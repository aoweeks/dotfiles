#!/bin/bash

LOG="/tmp/hypr_lid.log"

PID_FILE="$XDG_RUNTIME_DIR/lid-sleep-timer.pid"

echo "$(date '+%H:%M:%S') lid-open.sh: STARTED" >> "$LOG"

# Cancel pending sleep timer
if [ -f "$PID_FILE" ]; then
    kill "$(cat "$PID_FILE")" 2>/dev/null
    rm -f "$PID_FILE"
    echo "$(date '+%H:%M:%S') lid-open.sh: cancelled sleep timer" >> "$LOG"
fi

# Give the kernel/hardware a moment to restore power to the internal display
sleep 2

# Hyprland 0.56 handles DPMS better, so we can just rely on standard dpms on
# without forcing a DRM modeset which crashes the lockscreen.
hyprctl dispatch dpms on eDP-1

echo "$(date '+%H:%M:%S') lid-open.sh: DONE" >> "$LOG"
