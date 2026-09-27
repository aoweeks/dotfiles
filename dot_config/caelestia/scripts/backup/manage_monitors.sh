#!/bin/bash

# A clean, single script to handle all monitor and lid logic.

LOG="/tmp/hypr_monitor.log"
BUILDIN_DISPLAY_NAME="eDP-1"

echo "$(date '+%H:%M:%S') manage_monitors.sh called with: $1" >> "$LOG"

migrate_windows() {
    local target_mon="$1"
    echo "$(date '+%H:%M:%S') Migrating windows to $target_mon..." >> "$LOG"
    
    # Move windows one by one to avoid lockscreen/workspace crashes
    hyprctl clients -j | jq -c '.[] | select(.monitor == 0)' | while read -r client; do
        addr=$(echo "$client" | jq -r '.address')
        hyprctl dispatch movewindowmon "address:$addr" "$target_mon"
    done
    hyprctl dispatch focusmonitor "$target_mon"
}

case "$1" in
    "lid_close")
        # Check if an external monitor is connected
        external_count=$(hyprctl monitors -j | jq '[.[] | select(.name != "'"$BUILDIN_DISPLAY_NAME"'")] | length')
        if [ "$external_count" -gt 0 ]; then
            external_mon=$(hyprctl monitors -j | jq -r '.[] | select(.name != "'"$BUILDIN_DISPLAY_NAME"'") | .name' | head -n 1)
            migrate_windows "$external_mon"
        fi
        hyprctl dispatch dpms off "$BUILDIN_DISPLAY_NAME"
        ;;
        
    "lid_open")
        hyprctl dispatch dpms on "$BUILDIN_DISPLAY_NAME"
        ;;
        
    "monitor_connected")
        # If lid is closed, migrate windows to new monitor
        if grep -q "closed" /proc/acpi/button/lid/*/state 2>/dev/null; then
            external_mon=$(hyprctl monitors -j | jq -r '.[] | select(.name != "'"$BUILDIN_DISPLAY_NAME"'") | .name' | head -n 1)
            if [ -n "$external_mon" ]; then
                hyprctl dispatch dpms on "$external_mon"
                migrate_windows "$external_mon"
            fi
            hyprctl dispatch dpms off "$BUILDIN_DISPLAY_NAME"
        fi
        ;;
        
    "monitor_disconnected")
        if ! grep -q "closed" /proc/acpi/button/lid/*/state 2>/dev/null; then
            hyprctl dispatch dpms on "$BUILDIN_DISPLAY_NAME"
        fi
        ;;
        
    "daemon")
        echo "$(date '+%H:%M:%S') manage_monitors daemon STARTED" >> "$LOG"
        SOCKET_PATH="/tmp/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"
        
        # Start socat listener in background
        if [ -S "$SOCKET_PATH" ]; then
            socat -U - UNIX-CONNECT:"$SOCKET_PATH" | while read -r line; do
                if [[ "$line" == "monitoradded"* ]]; then
                    "$0" monitor_connected &
                elif [[ "$line" == "monitorremoved"* ]]; then
                    "$0" monitor_disconnected &
                fi
            done &
            SOCAT_PID=$!
        fi

        # Track lid state to avoid redundant calls
        LID_FILE="/proc/acpi/button/lid/*/state"
        if grep -q "closed" $LID_FILE 2>/dev/null; then
            LAST_STATE="closed"
        else
            LAST_STATE="open"
        fi

        while true; do
            if grep -q "closed" $LID_FILE 2>/dev/null; then
                current_state="closed"
            else
                current_state="open"
            fi
            
            if [ "$current_state" != "$LAST_STATE" ]; then
                echo "$(date '+%H:%M:%S') Daemon detected lid state change: $current_state" >> "$LOG"
                if [ "$current_state" == "closed" ]; then
                    "$0" lid_close &
                else
                    "$0" lid_open &
                fi
                LAST_STATE="$current_state"
            fi
            sleep 1
        done
        ;;
esac
