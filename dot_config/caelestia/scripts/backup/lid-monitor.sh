#!/bin/bash
# Monitors lid switch state and calls lid-close/lid-open scripts.
# Started via exec-once in Hyprland config.

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
LID_STATE_FILE="/proc/acpi/button/lid/LID0/state"
LAST_STATE=""
LOG="/tmp/hypr_lid.log"

# Read and apply initial state
if grep -q "closed" "$LID_STATE_FILE" 2>/dev/null; then
    LAST_STATE="closed"
    echo "$(date '+%H:%M:%S') lid-monitor.sh: initial state=closed, running lid-close.sh in 3s" >> "$LOG"
    # Delay slightly on startup to let Hyprland detect external monitors before we migrate workspaces
    (sleep 3 && "$SCRIPT_DIR/lid-close.sh") &
else
    LAST_STATE="open"
    echo "$(date '+%H:%M:%S') lid-monitor.sh: initial state=open, running lid-open.sh in 3s" >> "$LOG"
    # We don't necessarily need to trigger lid-open.sh on startup, but it's safe
    (sleep 3 && "$SCRIPT_DIR/lid-open.sh") &
fi

# Poll lid state (inotifywait doesn't work on /proc, so we poll)
while true; do
    current_state=$(awk '{print $2}' "$LID_STATE_FILE" 2>/dev/null)

    if [ "$current_state" != "$LAST_STATE" ]; then
        echo "$(date '+%H:%M:%S') lid-monitor.sh: state changed $LAST_STATE -> $current_state" >> "$LOG"
        if [ "$current_state" = "closed" ]; then
            "$SCRIPT_DIR/lid-close.sh" &
        elif [ "$current_state" = "open" ]; then
            "$SCRIPT_DIR/lid-open.sh" &
        fi
        LAST_STATE="$current_state"
    fi

    sleep 1
done
