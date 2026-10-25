#!/usr/bin/env bash
# ============================================================================
# GWR WiFi Captive Portal Auto-Reconnect
# ============================================================================
# Monitors connectivity and automatically re-authenticates when the
# GWR WiFi captive portal session times out.
#
# Flow:
#   1. Detects captive portal by checking internet connectivity / portal page
#   2. Fetches http://gwr.passengerwifi.com/ to retrieve session & CSRF tokens
#   3. POSTs to http://gwr.passengerwifi.com/login.php (accept terms & submit)
#   4. Follows redirect and clicks "Access Now" / secondary connect step if needed
#   5. Verifies internet access is restored
#
# Desktop notifications are sent at each stage via notify-send.
# ============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
PORTAL_DOMAIN="gwr.passengerwifi.com"
PORTAL_URL="http://${PORTAL_DOMAIN}/"
WIFI_SSID="GWR WiFi"
WIFI_IFACE="wlan0"

# Detection URL — plain HTTP endpoint that returns a known response when
# internet is working without redirection.
DETECT_URL="http://www.msftconnecttest.com/connecttest.txt"
DETECT_EXPECT="Microsoft Connect Test"

# How often to check (seconds)
CHECK_INTERVAL=30

# Notification settings
NOTIFY_ICON="network-wireless"
NOTIFY_TIMEOUT=8000  # milliseconds

# Retry settings
MAX_AUTH_RETRIES=3
RETRY_DELAY=3

# Cookie & session files
COOKIE_FILE="/tmp/gwr_wifi_cookies.txt"

# Logging
LOG_FILE="${HOME}/.gwr-wifi-reconnect.log"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
log() {
    local ts
    ts="$(date '+%Y-%m-%d %H:%M:%S')"
    echo "[${ts}] $*" | tee -a "${LOG_FILE}"
}

notify() {
    local urgency="${1}"
    local title="${2}"
    local body="${3}"
    notify-send \
        --urgency="${urgency}" \
        --icon="${NOTIFY_ICON}" \
        --expire-time="${NOTIFY_TIMEOUT}" \
        --app-name="GWR WiFi Reconnect" \
        "${title}" "${body}" 2>/dev/null || true
}

get_local_ip() {
    ip -4 addr show dev "${WIFI_IFACE}" 2>/dev/null \
        | grep -oP 'inet \K[\d.]+' \
        | head -1
}

get_mac() {
    ip link show "${WIFI_IFACE}" 2>/dev/null \
        | grep -oP 'ether \K[0-9a-f:]+' \
        | head -1
}

is_connected_to_ssid() {
    local active_ssid
    active_ssid="$(nmcli -t -f active,ssid dev wifi 2>/dev/null \
        | grep '^yes:' \
        | cut -d: -f2-)"
    [[ "${active_ssid}" == "${WIFI_SSID}" ]]
}

# ---------------------------------------------------------------------------
# Captive portal detection
# ---------------------------------------------------------------------------
# Returns 0 if internet is working (no captive portal), 1 if portal detected
check_internet() {
    local response
    response="$(curl -s --max-time 8 --connect-timeout 5 \
        -4 -o - "${DETECT_URL}" 2>/dev/null)" || return 1

    if [[ "${response}" == "${DETECT_EXPECT}" ]]; then
        return 0  # Internet is working
    else
        return 1  # Captive portal or no internet
    fi
}

# ---------------------------------------------------------------------------
# Portal authentication (PassengerWiFi / Nomad Digital flow)
# ---------------------------------------------------------------------------
authenticate() {
    rm -f "${COOKIE_FILE}"

    log "Step 1: Fetching initial GWR portal page..."
    local page1_html
    page1_html="$(curl -s -L -4 --max-time 10 --connect-timeout 5 \
        -c "${COOKIE_FILE}" "${PORTAL_URL}" 2>/dev/null)" || true

    if [[ -z "${page1_html}" ]]; then
        log "ERROR: Failed to fetch initial portal page at ${PORTAL_URL}"
        return 1
    fi

    # Extract hidden tokens (_token and _ceid)
    local token ceid
    token="$(echo "${page1_html}" | grep -zOP 'name="_token"[\s\S]*?value="\K[^"]+' 2>/dev/null | tr -d '\0' | head -n 1)" || true
    if [[ -z "${token}" ]]; then
        token="$(echo "${page1_html}" | grep -oP 'name="_token"\s+type="hidden"\s+value="\K[^"]+' | head -n 1)" || true
    fi

    ceid="$(echo "${page1_html}" | grep -zOP 'name="_ceid"[\s\S]*?value="\K[^"]+' 2>/dev/null | tr -d '\0' | head -n 1)" || true
    if [[ -z "${ceid}" ]]; then
        ceid="$(echo "${page1_html}" | grep -oP 'name="_ceid"\s+type="hidden"\s+value="\K[^"]+' | head -n 1)" || true
    fi

    log "Extracted _token: ${token:-'(none)'}, _ceid: ${ceid:-'1443'}"

    # --- Step 2: Accept terms & Submit ---
    log "Step 2: Submitting terms acceptance to ${PORTAL_DOMAIN}/login.php..."
    local step1_http_code
    step1_http_code="$(curl -s -o /dev/null -w '%{http_code}' \
        --max-time 10 --connect-timeout 5 \
        -b "${COOKIE_FILE}" -c "${COOKIE_FILE}" \
        -X POST "${PORTAL_URL}login.php" \
        -H "Host: ${PORTAL_DOMAIN}" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -H "Referer: ${PORTAL_URL}" \
        -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64; rv:137.0) Gecko/20100101 Firefox/137.0" \
        -d "_token=${token}&_ceid=${ceid:-1443}&form_type=registration&terms=1&lang=" \
        2>/dev/null)" || true

    log "Step 2 (terms submit) HTTP status code: ${step1_http_code}"

    sleep 1

    # --- Step 3: Fetch secondary page / Access Now screen ---
    log "Step 3: Accessing confirmation / secondary page..."
    local page2_html
    page2_html="$(curl -s -L -4 --max-time 10 --connect-timeout 5 \
        -b "${COOKIE_FILE}" -c "${COOKIE_FILE}" "${PORTAL_URL}" 2>/dev/null)" || true

    # Check if there is a secondary form or 'connect' action on Page 2
    local page2_action
    page2_action="$(echo "${page2_html}" | grep -zOP '<form[^>]+action="\K[^"]+' 2>/dev/null | tr -d '\0' | head -n 1)" || true

    if [[ -n "${page2_action}" && "${page2_action}" != "login.php"* ]]; then
        log "Step 4: Submitting secondary form to ${page2_action}..."
        curl -s -o /dev/null --max-time 10 --connect-timeout 5 \
            -b "${COOKIE_FILE}" -c "${COOKIE_FILE}" \
            -X POST "${PORTAL_URL}${page2_action#/}" \
            -H "Referer: ${PORTAL_URL}" \
            -d "terms=1&accept=Access+Now" \
            2>/dev/null || true
    fi

    # Give firewall rules a moment to update
    sleep 2
    return 0
}

# ---------------------------------------------------------------------------
# Full reconnection attempt with retries
# ---------------------------------------------------------------------------
attempt_reconnect() {
    local attempt

    notify "critical" \
        "⚠️  Captive Portal Detected" \
        "GWR WiFi session has expired.\nAttempting automatic reconnection..."

    log "Captive portal detected — starting reconnection"

    for attempt in $(seq 1 "${MAX_AUTH_RETRIES}"); do
        log "Authentication attempt ${attempt}/${MAX_AUTH_RETRIES}"

        if authenticate; then
            # Verify internet is back
            if check_internet; then
                log "SUCCESS: Internet access restored on attempt ${attempt}"
                notify "normal" \
                    "✅  WiFi Reconnected" \
                    "Successfully re-authenticated to GWR WiFi.\nInternet access has been restored."
                return 0
            else
                log "Auth completed but internet check failed, retrying..."
            fi
        fi

        if [[ "${attempt}" -lt "${MAX_AUTH_RETRIES}" ]]; then
            log "Waiting ${RETRY_DELAY}s before retry..."
            sleep "${RETRY_DELAY}"
        fi
    done

    log "FAILED: Could not restore internet after ${MAX_AUTH_RETRIES} attempts"
    notify "critical" \
        "❌  Reconnection Failed" \
        "Could not re-authenticate after ${MAX_AUTH_RETRIES} attempts.\nYou may need to reconnect manually via ${PORTAL_URL}"
    return 1
}

# ---------------------------------------------------------------------------
# Main loop
# ---------------------------------------------------------------------------
main() {
    log "========================================="
    log "GWR WiFi auto-reconnect started"
    log "SSID: ${WIFI_SSID}"
    log "Portal: ${PORTAL_DOMAIN}"
    log "Check interval: ${CHECK_INTERVAL}s"
    log "========================================="

    notify "low" \
        "🛜  WiFi Monitor Active" \
        "Monitoring GWR WiFi connection.\nChecking every ${CHECK_INTERVAL} seconds."

    local consecutive_failures=0
    local last_check_ts
    last_check_ts="$(date +%s)"

    while true; do
        local now elapsed
        now="$(date +%s)"
        elapsed=$((now - last_check_ts))

        # Detect wake-from-sleep: pre-set failure counter so a single
        # failed check triggers immediate reconnection.
        if [[ "${elapsed}" -gt $((CHECK_INTERVAL * 2)) ]]; then
            log "Wake from sleep detected (${elapsed}s since last check)"
            consecutive_failures=1
        fi
        last_check_ts="${now}"

        # Only act if we're connected to the right SSID
        if ! is_connected_to_ssid; then
            consecutive_failures=0
            sleep "${CHECK_INTERVAL}"
            continue
        fi

        if check_internet; then
            if [[ "${consecutive_failures}" -gt 0 ]]; then
                log "Internet connectivity restored"
            fi
            consecutive_failures=0
        else
            consecutive_failures=$((consecutive_failures + 1))
            log "Internet check failed (${consecutive_failures} consecutive)"

            # Wait for 2 consecutive failures to avoid false positives
            if [[ "${consecutive_failures}" -ge 2 ]]; then
                attempt_reconnect || true
                consecutive_failures=0
                # Extra cooldown after reconnection attempt
                sleep 5
            fi
        fi

        sleep "${CHECK_INTERVAL}"
    done
}

# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------
trap 'log "Shutting down..."; rm -f "${COOKIE_FILE}"; exit 0' SIGINT SIGTERM

main "$@"
