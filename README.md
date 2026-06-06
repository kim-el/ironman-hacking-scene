# Claude Iron Man Hacking Scene

Multi-window AI research grid — 5 terminal windows tiled across your desktop, each running an AI agent doing deep research in parallel. Looks like the Iron Man Senate hearing hacking scene.

Built with [claw](https://github.com/soongenwong/claudecode) (Rust Claude Code, 17 MB per instance) + [kitty](https://sw.kovidgoyal.net/kitty/) terminal emulator.

```
[quantum-computing] [AI-regulation] [climate-tech] [exoplanets] [web-dev]
      ▁▂▃▄▅▆▇█        ▁▂▃▄▅▆▇█       ▁▂▃▄▅▆▇█      ▁▂▃▄▅▆▇█      ▁▂▃▄▅▆▇█
   ⠋ scanning...     ⠹ processing...   ⠇ compiling...    ⠏ fetching...    ⠴ analyzing...
```

## What it does

- Spawns 5 kitty windows tiled side-by-side
- Each runs [claw](https://github.com/soongenwong/claudecode) (Rust AI coding agent, 17 MB RAM each)
- Live pulsing progress bar during AI processing
- Typewriter-effect answer reveal
- Wikipedia search proxy (DuckDuckGo blocked in some regions)
- Total RAM: ~85 MB (5 × 17 MB) vs 2+ GB with Node.js agents

## Quick Start

```bash
# 1. Install dependencies
brew install kitty
# claw must be built from source: https://github.com/soongenwong/claudecode

# 2. Set your API key
export ANTHROPIC_API_KEY="sk-..."
export ANTHROPIC_BASE_URL="https://api.deepseek.com/anthropic"  # if using proxy
export ANTHROPIC_MODEL="deepseek-v4-pro"

# 3. Start the search proxy (optional, for Wikipedia search)
python3 proxy/search_proxy.py &

# 4. Launch kitty with remote control
/Applications/kitty.app/Contents/MacOS/kitty \
  -o allow_remote_control=yes \
  --listen-on unix:/tmp/mykitty &

# 5. Run the grid
bash ironman_kitty.sh
```

## Components

| Component | Purpose | Size |
|-----------|---------|------|
| `bin/claw-apt` | Streaming wrapper with pulsing bar + typewriter | ~200 lines bash |
| `bin/status-panel` | Dynamic TUI monitor spawner | ~80 lines bash |
| `proxy/search_proxy.py` | Wikipedia search backend | ~80 lines Python |
| `ironman_kitty.sh` | Grid launcher (spawns 5 windows) | ~60 lines bash |
| `config/kitty.conf` | Kitty terminal theme (Claude Code colors) | ~40 lines |
| `skills/verify/` | Verification engineering harness (`/verify`) | Claude Code skill |
| `commands/` | Slash commands (`/verify`, `/spawn`, `/cancel`) | Claude Code extensions |

## Profiles (in `claw-apt`)

```bash
claw-apt --profile hacker "query"    # blue pulsing bar, fast typewriter
claw-apt --profile apt "query"       # green, medium speed
claw-apt --profile ghost "query"     # silent, raw output only
claw-apt --profile verbose "query"   # magenta, full details
```

Default: hacker profile with blue bar.

## Verification Harness

The `/verify` skill runs a 5-phase verification loop:

1. **Language detection** — picks the right test framework
2. **Property-based tests** — generates invariant tests
3. **Interaction matrix** — tests A→B function pipelines
4. **Adversarial agent** — spawns a sub-agent to break the code
5. **Structured report** — PASS/FAIL with all fixes documented

Usage: `/verify <file_or_directory>` in Claude Code.

## Tech Stack

- **Terminal**: [kitty](https://sw.kovidgoyal.net/kitty/) (GPU-rendered, 10 MB/window)
- **AI Agent**: [claw](https://github.com/soongenwong/claudecode) (Rust, 17 MB per instance)
- **Font**: JetBrains Mono 12pt
- **Theme**: Claude Code-inspired (Tokyo Night derivative)
- **Search**: Wikipedia API proxy (Python, ~5 MB)

## License

MIT — hack freely.
