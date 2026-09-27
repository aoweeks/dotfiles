#!/bin/bash

LOG="/tmp/hypr_lid.log"

BUILDIN_DISPLAY_NAME="eDP-1"

echo "$(date '+%H:%M:%S') monitor_connected.sh: STARTED" >> "$LOG"

# Check if the lid is currently closed
if grep -q "closed" /proc/acpi/button/lid/*/state 2>/dev/null; then
    echo "$(date '+%H:%M:%S') monitor_connected.sh: lid is closed" >> "$LOG"
    # Lid is closed: migrate workspaces to the external monitor and turn off the screen
    # Wait up to 5 seconds for Hyprland to fully register the new monitor
    for i in {1..25}; do
        external_mon=$(hyprctl monitors -j | jq -r '.[] | select(.name != "eDP-1") | .name' | head -n 1)
        if [ -n "$external_mon" ]; then
            break
        fi
        sleep 0.2
    done

    echo "$(date '+%H:%M:%S') monitor_connected.sh: external_mon='$external_mon'" >> "$LOG"

    if [ -n "$external_mon" ]; then
        hyprctl dispatch dpms on "$external_mon"
        for ws in $(hyprctl workspaces -j | jq -r '.[] | select(.monitor == "eDP-1") | .name'); do
            echo "$(date '+%H:%M:%S') monitor_connected.sh: moving workspace $ws to $external_mon" >> "$LOG"
            hyprctl dispatch moveworkspacetomonitor "$ws" "$external_mon"
        done
        hyprctl dispatch focusmonitor "$external_mon"
    fi
    hyprctl dispatch dpms off "$BUILDIN_DISPLAY_NAME"
else
    echo "$(date '+%H:%M:%S') monitor_connected.sh: lid is open" >> "$LOG"
    # Lid is open: leave DPMS on
    hyprctl dispatch dpms on "$BUILDIN_DISPLAY_NAME"
fi

echo "$(date '+%H:%M:%S') monitor_connected.sh: DONE" >> "$LOG"
