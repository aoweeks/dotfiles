#!/bin/bash

notify-send "Success!"

BUILDIN_DISPLAY_NAME="eDP-1"  # Get the name of buildin display using "hyprctl monitors all"
# Only turn the screen back on if the lid is open
if ! grep -q "closed" /proc/acpi/button/lid/*/state 2>/dev/null; then
    hyprctl dispatch dpms on "$BUILDIN_DISPLAY_NAME"
fi
