#!/bin/bash

# A robust socket listener to replace the buggy hyprland-monitor-attached binary

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
LOG="/tmp/hypr_lid.log"

if [ -z "$HYPRLAND_INSTANCE_SIGNATURE" ]; then
    echo "$(date '+%H:%M:%S') monitor-listener.sh: no HYPRLAND_INSTANCE_SIGNATURE, exiting" >> "$LOG"
    exit 1
fi

SOCKET_PATH="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"

echo "$(date '+%H:%M:%S') monitor-listener.sh: STARTED, socket=$SOCKET_PATH" >> "$LOG"

# Background listener to restart Quickshell after waking from sleep
(
    journalctl -u systemd-suspend.service -f | while read -r line; do
        if echo "$line" | grep -q "Finished System Suspend"; then
            echo "$(date '+%H:%M:%S') monitor-listener.sh: woke from suspend, restarting quickshell" >> "$LOG"
            # Wait for Hyprland to finish its own resume routines
            sleep 2
            qs -c caelestia kill 2>/dev/null
            sleep 0.5
            hyprctl dispatch exec "caelestia shell -d"
        fi
    done
) &

# Keep reconnecting to the socket if it drops
while true; do
    echo "$(date '+%H:%M:%S') monitor-listener.sh: connecting to socket..." >> "$LOG"
    socat -U - UNIX-CONNECT:"$SOCKET_PATH" 2>/dev/null | while read -r line; do
        echo "$(date '+%H:%M:%S') monitor-listener.sh: event='$line'" >> "$LOG"
        if [[ "$line" == monitoradded* ]]; then
            "$SCRIPT_DIR/monitor_connected.sh" &
        elif [[ "$line" == monitorremoved* ]]; then
            "$SCRIPT_DIR/monitor_disconnected.sh" &
        fi
    done
    echo "$(date '+%H:%M:%S') monitor-listener.sh: socat disconnected, reconnecting in 2s..." >> "$LOG"
    sleep 2
    # Check the socket still exists (Hyprland might have restarted)
    if [ ! -S "$SOCKET_PATH" ]; then
        echo "$(date '+%H:%M:%S') monitor-listener.sh: socket gone, exiting" >> "$LOG"
        break
    fi
done
