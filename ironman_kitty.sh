#!/bin/bash
# Iron Man grid - kitty edition
# Uses kitty remote control + osascript for window positioning

SOCKET="unix:/tmp/mykitty"
TOPICS=(
  "quantum computing breakthroughs 2026"
  "AI regulation global 2026"
  "climate tech fusion batteries 2026"
  "exoplanet space discoveries 2026"
  "web development trends 2026"
)

# Close the initial window (id 1) - we'll spawn 5 fresh ones
kitty @ --to "$SOCKET" close-window --match id:1 2>/dev/null

# Spawn 5 windows, capture their IDs
declare -a WIN_IDS
for i in 1 2 3 4 5; do
  WIN_ID=$(kitty @ --to "$SOCKET" launch --type=os-window /opt/homebrew/bin/opencode 2>&1)
  WIN_IDS+=("$WIN_ID")
  echo "Spawned window $i: ID=$WIN_ID"
done

# Wait for all opencode TUIs to load
sleep 1.5

# Send search queries to each window
for i in 1 2 3 4 5; do
  ID="${WIN_IDS[$((i-1))]}"
  TOPIC="${TOPICS[$((i-1))]}"
  kitty @ --to "$SOCKET" send-text --match "id:$ID" "$TOPIC\n"
  echo "Fired query to window ID=$ID: $TOPIC"
done

sleep 0.3

# Position windows with osascript
osascript - "$@" <<'APPLESCRIPT' 2>/dev/null
tell application "Finder"
    set screenBounds to bounds of window of desktop
end tell
set sw to item 3 of screenBounds
set sh to item 4 of screenBounds

set winW to 490
set winH to 370
set gap to 10
set topY to 50
set row2Y to topY + winH + gap

set row1W to (winW * 3) + (gap * 2)
set row2W to (winW * 2) + (gap * 1)
set row1Start to (sw - row1W) / 2
set row2Start to (sw - row2W) / 2

-- positions for 5 windows: 3 top row, 2 bottom row centered
set xList to {row1Start, row1Start + winW + gap, row1Start + (winW + gap) * 2, row2Start, row2Start + winW + gap}
set yList to {topY, topY, topY, row2Y, row2Y}

tell application "System Events"
    set kittyWindows to every window of process "kitty"
end tell

tell application "Terminal"
    activate
end tell
delay 0.1

-- Bring kitty to front and position each window
tell application "kitty" to activate
delay 0.2

repeat with i from 1 to 5
    set xPos to item i of xList
    set yPos to item i of yList

    set windowList to {}
    tell application "System Events"
        set windowList to every window of process "kitty"
    end tell

    if (count of windowList) >= i then
        tell application "System Events"
            set theWindow to item i of windowList
            set position of theWindow to {xPos, yPos}
            set size of theWindow to {winW, winH}
        end tell
    end if
end repeat
APPLESCRIPT

echo "Done - 5 windows should be grid-positioned"
