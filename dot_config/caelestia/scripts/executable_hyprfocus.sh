#!/bin/bash
while [[ $# -gt 0 ]]; do
  case $1 in
    -c|--client)
      CLIENT="$2"
      shift 2
      ;;
    -l|--launcher)
      LAUNCHER="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

if [ -z "$CLIENT" ] || [ -z "$LAUNCHER" ]; then
    echo "Usage: hyprfocus.sh --client <class> --launcher <cmd>"
    exit 1
fi

ADDRESSES=($(hyprctl clients -j | jq -r "map(select(.class == \"$CLIENT\")) | sort_by(.focusHistoryID) | .[].address"))
ACTIVE_ADDR=$(hyprctl activewindow -j | jq -r ".address")

if [ ${#ADDRESSES[@]} -eq 0 ]; then
    hyprctl dispatch "hl.dsp.exec_cmd(\"$LAUNCHER\")"
    exit 0
fi

TARGET="${ADDRESSES[0]}"
if [ "$ACTIVE_ADDR" == "$TARGET" ] && [ ${#ADDRESSES[@]} -gt 1 ]; then
    TARGET="${ADDRESSES[1]}"
fi

hyprctl dispatch "hl.dsp.focus({ window = \"address:$TARGET\" })"
