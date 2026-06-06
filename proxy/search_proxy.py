"""Search proxy: claw ?q= → Wikipedia API → DuckDuckGo-style HTML."""
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs, quote
from urllib.request import urlopen, Request
from html import escape
import json
import re
import time
import sys

PORT = 8889

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        params = parse_qs(urlparse(self.path).query)
        query = params.get('q', [''])[0].strip()
        if not query:
            self.send_error(400, "Missing or empty query")
            return
        try:
            results = wikipedia_search(query)
            html = format_html(query, results)
            self.send_response(200)
            self.send_header('Content-type', 'text/html; charset=utf-8')
            self.send_header('Content-Length', str(len(html.encode())))
            self.end_headers()
            self.wfile.write(html.encode())
        except Exception:
            self.send_error(500, "Internal server error")

    def log_message(self, format, *args):
        pass

def wikipedia_search(query, limit=8):
    url = (
        "https://en.wikipedia.org/w/api.php"
        f"?action=query&list=search&srsearch={quote(query)}&srlimit={limit}&format=json"
    )
    req = Request(url, headers={'User-Agent': 'search-proxy/1.0'})
    for attempt in range(3):
        try:
            with urlopen(req, timeout=10) as resp:
                data = json.loads(resp)
            return data.get('query', {}).get('search', [])
        except Exception:
            if attempt < 2:
                time.sleep(0.5 * (attempt + 1))
            else:
                return []

TAG_RE = re.compile(r'<[^>]*>')

def strip_html(text):
    return TAG_RE.sub('', text)

def format_html(query, results):
    links = []
    for r in results:
        title = escape(r['title'])
        url = f"https://en.wikipedia.org/wiki/{quote(r['title'].replace(' ', '_'))}"
        snippet = escape(strip_html(r.get('snippet', '')))
        links.append(
            f'<a rel="nofollow" class="result__a" href="{url}">{title}</a>'
            f'<span class="result__snippet">{snippet}</span>'
        )
    result_html = ''.join(f'<div class="result">{l}</div>' for l in links)
    if not links:
        result_html = '<p>No results found.</p>'
    return f"""<!DOCTYPE html>
<html><head><meta charset="utf-8"><title>Search: {escape(query)}</title></head><body>
<h2>Results for: {escape(query)}</h2>
<div class="results">
{result_html}
</div></body></html>"""

if __name__ == '__main__':
    print(f"proxy :{PORT}", file=sys.stderr)
    HTTPServer(('127.0.0.1', PORT), Handler).serve_forever()
