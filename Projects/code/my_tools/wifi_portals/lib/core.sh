#!/usr/bin/env bash
# ============================================================================
# WiFi Portal Reconnect Framework — Core Library
# ============================================================================

LOG_FILE="${HOME}/.wifi-portal-reconnect.log"

# ---------------------------------------------------------------------------
# Logging & Notifications
# ---------------------------------------------------------------------------
log() {
    local ts
    ts="$(date '+%Y-%m-%d %H:%M:%S')"
    echo "[${ts}] $*" | tee -a "${LOG_FILE}"
}

# Resolve icon to absolute path if possible to prevent "missing image" errors
resolve_icon() {
    local icon_name="$1"
    # Prefer breeze-dark as CachyOS is typically dark mode
    if [[ -f "/usr/share/icons/breeze-dark/status/22/${icon_name}.svg" ]]; then
        echo "/usr/share/icons/breeze-dark/status/22/${icon_name}.svg"
    elif [[ -f "/usr/share/icons/breeze/status/22/${icon_name}.svg" ]]; then
        echo "/usr/share/icons/breeze/status/22/${icon_name}.svg"
    elif [[ -f "/usr/share/icons/breeze-dark/devices/22/${icon_name}.svg" ]]; then
        echo "/usr/share/icons/breeze-dark/devices/22/${icon_name}.svg"
    elif [[ -f "/usr/share/icons/breeze/devices/22/${icon_name}.svg" ]]; then
        echo "/usr/share/icons/breeze/devices/22/${icon_name}.svg"
    else
        echo "${icon_name}"
    fi
}

notify() {
    local urgency="${1}"
    local title="${2}"
    local body="${3}"
    local raw_icon="${4:-network-wireless}"
    local icon
    icon="$(resolve_icon "${raw_icon}")"

    notify-send \
        --urgency="${urgency}" \
        --icon="${icon}" \
        --expire-time=8000 \
        --app-name="WiFi Portal Reconnect" \
        "${title}" "${body}" 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# WiFi Interface & SSID Discovery
# ---------------------------------------------------------------------------

# Get the active WiFi SSID
get_active_ssid() {
    nmcli -t -f active,ssid dev wifi 2>/dev/null \
        | grep '^yes:' \
        | cut -d: -f2-
}

# Auto-detect which WiFi interface is currently connected (wlan0, wlan1, etc.)
# Returns the interface name, not hardcoded.
get_wifi_interface() {
    # Find the wifi device in "connected" state
    local iface
    iface="$(nmcli -t -f DEVICE,TYPE,STATE dev 2>/dev/null \
        | awk -F: '$2=="wifi" && $3=="connected" {print $1; exit}')"

    if [[ -n "${iface}" ]]; then
        echo "${iface}"
        return 0
    fi

    # Fallback: check ip route for default via a wireless interface
    iface="$(ip route show default 2>/dev/null \
        | grep -oP 'dev \K\S+' \
        | head -1)"

    if [[ -n "${iface}" ]]; then
        echo "${iface}"
        return 0
    fi

    echo "wlan0"  # Last resort fallback
}

# ---------------------------------------------------------------------------
# IP / MAC / Signal Helpers (all use dynamic interface)
# ---------------------------------------------------------------------------

get_local_ip() {
    local iface="${1:-$(get_wifi_interface)}"
    ip -4 addr show dev "${iface}" 2>/dev/null \
        | grep -oP 'inet \K[\d.]+' \
        | head -1
}

get_mac() {
    local iface="${1:-$(get_wifi_interface)}"
    ip link show "${iface}" 2>/dev/null \
        | grep -oP 'ether \K[0-9a-f:]+' \
        | head -1
}

# Get WiFi signal strength as a percentage (0-100).
# Returns empty string if unavailable.
get_signal_strength() {
    # nmcli reports signal as 0-100 percentage for the active (*) connection
    nmcli -t -f IN-USE,SIGNAL dev wifi 2>/dev/null \
        | grep '^\*:' \
        | cut -d: -f2
}

# Classify signal strength into a human-readable label
classify_signal() {
    local pct="${1:-0}"
    if [[ "${pct}" -ge 70 ]]; then
        echo "good (${pct}%)"
    elif [[ "${pct}" -ge 40 ]]; then
        echo "weak (${pct}%)"
    elif [[ "${pct}" -ge 1 ]]; then
        echo "very weak (${pct}%)"
    else
        echo "no signal (${pct}%)"
    fi
}

# ---------------------------------------------------------------------------
# Connectivity Checks
# ---------------------------------------------------------------------------

# Generic internet check.
# Returns:
#   0 = Internet is working
#   1 = Portal is intercepting us
#   2 = Network/Signal failure (timeout/unreachable)
check_internet_generic() {
    local detect_url="http://www.msftconnecttest.com/connecttest.txt"
    local detect_expect="Microsoft Connect Test"
    local response
    local iface
    iface="$(get_wifi_interface)"

    response="$(curl -s -4 --max-time 8 --connect-timeout 5 \
        --interface "${iface}" \
        -o - "${detect_url}" 2>/dev/null)" || return 2

    if [[ "${response}" == "${detect_expect}" ]]; then
        return 0
    else
        return 1
    fi
}
