#!/usr/bin/env bash
# safe-close.sh — Require double Super+Q press to close a window.
#
# First press:  adds 'safe_close_pending' tag to window & refreshes props -> border turns closingWindowBorderColour.
# Second press: within TIMEOUTs on same window -> closes window.
# Timeout or focus change -> removes tag & refreshes props -> border animates back to normal.

STATE_FILE="/tmp/hypr-safe-close-state"
TIMEOUT=2

get_active_address() {
    hyprctl activewindow -j 2>/dev/null \
        | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('address',''))" 2>/dev/null
}

tag_window() {
    local addr="$1"
    [[ -z "$addr" ]] && return
    hyprctl eval "
        hl.dispatch(hl.dsp.window.tag({ tag = '+safe_close_pending', window = 'address:$addr' }))
        hl.exec_scheduled_prop_refresh_immediately()
    " >/dev/null 2>&1
}

untag_window() {
    local addr="$1"
    [[ -z "$addr" ]] && return
    hyprctl eval "
        hl.dispatch(hl.dsp.window.tag({ tag = '-safe_close_pending', window = 'address:$addr' }))
        hl.exec_scheduled_prop_refresh_immediately()
    " >/dev/null 2>&1
}

clear_state_and_untag() {
    if [[ -f "$STATE_FILE" ]]; then
        local old_addr
        old_addr=$(cut -d'|' -f1 "$STATE_FILE" 2>/dev/null)
        rm -f "$STATE_FILE"
        if [[ -n "$old_addr" ]]; then
            untag_window "$old_addr"
        fi
    fi
}

# ── --reset flag (called when focus changes away from pending window) ────────
if [[ "$1" == "--reset" ]]; then
    clear_state_and_untag
    exit 0
fi

# ── main logic ───────────────────────────────────────────────────────────────
CURRENT_ADDR=$(get_active_address)
[[ -z "$CURRENT_ADDR" ]] && exit 0

NOW=$(date +%s)

if [[ -f "$STATE_FILE" ]]; then
    IFS='|' read -r PENDING_ADDR PENDING_TIME < "$STATE_FILE"
    ELAPSED=$(( NOW - PENDING_TIME ))

    if [[ "$CURRENT_ADDR" == "$PENDING_ADDR" && $ELAPSED -lt $TIMEOUT ]]; then
        # ✅ Second press within 3s on same window -> close it
        clear_state_and_untag
        hyprctl eval "hl.dispatch(hl.dsp.window.close())" >/dev/null 2>&1
        exit 0
    else
        # Timed out or different window -> untag previous window
        clear_state_and_untag
    fi
fi

# First press -> set state, add tag, trigger property refresh
printf '%s|%s\n' "$CURRENT_ADDR" "$NOW" > "$STATE_FILE"
tag_window "$CURRENT_ADDR"

# Background timeout (3s)
(
    sleep "$TIMEOUT"
    if [[ -f "$STATE_FILE" ]]; then
        IFS='|' read -r stored_addr _ < "$STATE_FILE" 2>/dev/null
        if [[ "$stored_addr" == "$CURRENT_ADDR" ]]; then
            rm -f "$STATE_FILE"
            untag_window "$CURRENT_ADDR"
        fi
    fi
) &
disown
