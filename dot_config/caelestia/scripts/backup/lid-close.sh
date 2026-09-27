#!/bin/bash

LOG="/tmp/hypr_lid.log"

# ── Adjust this to match your hyprland.conf monitor line for eDP-1 ──
EDP_CONFIG="eDP-1, preferred, auto, 1.25"

PID_FILE="$XDG_RUNTIME_DIR/lid-sleep-timer.pid"

echo "$(date '+%H:%M:%S') lid-close.sh: STARTED" >> "$LOG"

# Cancel any previous timer
if [ -f "$PID_FILE" ]; then
    kill "$(cat "$PID_FILE")" 2>/dev/null
    rm -f "$PID_FILE"
fi

# Check if any external monitor is connected
external_count=$(hyprctl monitors -j | jq '[.[] | select(.name | startswith("eDP") | not)] | length')
echo "$(date '+%H:%M:%S') lid-close.sh: external_count=$external_count" >> "$LOG"

if [ "$external_count" -gt 0 ]; then
    # Migrate all workspaces from eDP-1 to the external monitor
    external_mon=$(hyprctl monitors -j | jq -r '.[] | select(.name != "eDP-1") | .name' | head -n 1)
    echo "$(date '+%H:%M:%S') lid-close.sh: external_mon=$external_mon" >> "$LOG"
    if [ -n "$external_mon" ]; then
        for ws in $(hyprctl workspaces -j | jq -r '.[] | select(.monitor == "eDP-1") | .name'); do
            echo "$(date '+%H:%M:%S') lid-close.sh: moving workspace $ws to $external_mon" >> "$LOG"
            hyprctl dispatch moveworkspacetomonitor "$ws" "$external_mon"
        done
        hyprctl dispatch focusmonitor "$external_mon"
    fi
fi

# Always turn off the built-in screen when the lid is closed
echo "$(date '+%H:%M:%S') lid-close.sh: dpms off eDP-1" >> "$LOG"
hyprctl dispatch dpms off eDP-1

# 2-minute sleep timer
(
    sleep 120

    ac_connected=0
    for ps in /sys/class/power_supply/*/; do
        if [ "$(cat "${ps}type" 2>/dev/null)" = "Mains" ] && \
           [ "$(cat "${ps}online" 2>/dev/null)" = "1" ]; then
            ac_connected=1
            break
        fi
    done

    if [ "$ac_connected" -eq 0 ]; then
        echo "$(date '+%H:%M:%S') lid-close.sh: timer expired, suspending" >> "$LOG"
        systemctl suspend
    else
        echo "$(date '+%H:%M:%S') lid-close.sh: timer expired, AC connected, not suspending" >> "$LOG"
    fi

    rm -f "$PID_FILE"
) &

echo $! > "$PID_FILE"
echo "$(date '+%H:%M:%S') lid-close.sh: DONE, timer PID=$!" >> "$LOG"
