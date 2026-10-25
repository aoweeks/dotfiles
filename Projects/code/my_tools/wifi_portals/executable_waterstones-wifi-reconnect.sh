#!/usr/bin/env bash
# ============================================================================
# Waterstones WiFi Captive Portal Auto-Reconnect
# ============================================================================
# Monitors connectivity and automatically re-authenticates when the
# Waterstones WiFi captive portal session times out.
#
# Flow:
#   1. Detects captive portal by checking HTTP response from a known URL
#   2. POSTs to http://192.168.1.1/index.php (accept terms + connect)
#   3. POSTs to the Aruba controller auth endpoint (start browsing)
#   4. Verifies internet access is restored
#
# Desktop notifications are sent at each stage.
# ============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
PORTAL_IP="192.168.1.1"
WIFI_SSID="_Waterstones WiFi"
WIFI_IFACE="wlan0"

# Detection URL — plain HTTP endpoint that returns a known response when
# the internet is working. A captive portal will either redirect or return
# different content.
DETECT_URL="http://www.msftconnecttest.com/connecttest.txt"
DETECT_EXPECT="Microsoft Connect Test"

# How often to check (seconds)
CHECK_INTERVAL=30

# Aruba controller auth endpoint (discovered from portal second page)
CONTROLLER_URL="http://10.255.76.251:8002/index.php?zone=waterstones"

# Shared credentials embedded in the portal form
AUTH_USER="user1"
AUTH_PASS="user1"
PORTAL_ZONE="waterstones"
REDIR_URL="http://wifi.waterstones.com"

# Notification settings
NOTIFY_ICON="network-wireless"
NOTIFY_TIMEOUT=8000  # milliseconds

# Retry settings
MAX_AUTH_RETRIES=3
RETRY_DELAY=3

# Logging
LOG_FILE="${HOME}/.waterstones-wifi-reconnect.log"

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
        --app-name="WiFi Reconnect" \
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
# Portal authentication (two-step flow)
# ---------------------------------------------------------------------------
authenticate() {
    local ip mac
    ip="$(get_local_ip)"
    mac="$(get_mac)"

    if [[ -z "${ip}" || -z "${mac}" ]]; then
        log "ERROR: Could not determine local IP or MAC address"
        return 1
    fi

    log "Local IP: ${ip}, MAC: ${mac}"

    # --- Step 1: Accept terms & connect ---
    log "Step 1: Submitting terms acceptance to portal..."
    local step1_response step1_http_code
    step1_http_code="$(curl -s -o /dev/null -w '%{http_code}' \
        --max-time 10 --connect-timeout 5 \
        -X POST "http://${PORTAL_IP}/index.php" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -H "Referer: http://${PORTAL_IP}/" \
        -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64; rv:137.0) Gecko/20100101 Firefox/137.0" \
        -d "aup=on&auth_user=${AUTH_USER}&auth_pass=${AUTH_PASS}&zone=${PORTAL_ZONE}&devicetype=desktop&ipaddress=${ip}&user_mac=${mac}&redirurl=${REDIR_URL}&accept=Connect" \
        2>/dev/null)" || true

    log "Step 1 response code: ${step1_http_code}"

    # Accept 200, 301, 302, 303, 307 as success (redirects are expected)
    if [[ ! "${step1_http_code}" =~ ^(200|301|302|303|307)$ ]]; then
        log "WARNING: Step 1 returned unexpected code ${step1_http_code}"
    fi

    sleep 1

    # --- Step 2: Click "Start Browsing" (authenticate with Aruba controller) ---
    log "Step 2: Authenticating with controller..."
    local step2_http_code
    step2_http_code="$(curl -s -o /dev/null -w '%{http_code}' \
        --max-time 10 --connect-timeout 5 \
        -X POST "${CONTROLLER_URL}" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -H "Referer: http://${PORTAL_IP}/authenticate.php" \
        -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64; rv:137.0) Gecko/20100101 Firefox/137.0" \
        -d "auth_user=${AUTH_USER}&auth_pass=${AUTH_PASS}&redirurl=${REDIR_URL}&zone=${PORTAL_ZONE}&accept=Start+Browsing" \
        2>/dev/null)" || true

    log "Step 2 response code: ${step2_http_code}"

    # Give the controller a moment to update firewall rules
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
        "Waterstones WiFi session has expired.\nAttempting automatic reconnection..."

    log "Captive portal detected — starting reconnection"

    for attempt in $(seq 1 "${MAX_AUTH_RETRIES}"); do
        log "Authentication attempt ${attempt}/${MAX_AUTH_RETRIES}"

        if authenticate; then
            # Verify internet is back
            if check_internet; then
                log "SUCCESS: Internet access restored on attempt ${attempt}"
                notify "normal" \
                    "✅  WiFi Reconnected" \
                    "Successfully re-authenticated to Waterstones WiFi.\nInternet access has been restored."
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
        "Could not re-authenticate after ${MAX_AUTH_RETRIES} attempts.\nYou may need to reconnect manually via http://${PORTAL_IP}/"
    return 1
}

# ---------------------------------------------------------------------------
# Main loop
# ---------------------------------------------------------------------------
main() {
    log "========================================="
    log "Waterstones WiFi auto-reconnect started"
    log "SSID: ${WIFI_SSID}"
    log "Portal: ${PORTAL_IP}"
    log "Check interval: ${CHECK_INTERVAL}s"
    log "========================================="

    notify "low" \
        "🛜  WiFi Monitor Active" \
        "Monitoring Waterstones WiFi connection.\nChecking every ${CHECK_INTERVAL} seconds."

    local consecutive_failures=0
    local last_check_ts
    last_check_ts="$(date +%s)"

    while true; do
        local now elapsed
        now="$(date +%s)"
        elapsed=$((now - last_check_ts))

        # Detect wake-from-sleep: if elapsed time is much longer than the
        # check interval, the laptop was asleep. Pre-set failure counter so
        # a single failed check triggers immediate reconnection.
        if [[ "${elapsed}" -gt $((CHECK_INTERVAL * 2)) ]]; then
            log "Wake from sleep detected (${elapsed}s since last check)"
            consecutive_failures=1
        fi
        last_check_ts="${now}"

        # Only act if we're connected to the right SSID
        if ! is_connected_to_ssid; then
            log "Not connected to ${WIFI_SSID}, skipping check"
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
# Handle signals gracefully
trap 'log "Shutting down..."; exit 0' SIGINT SIGTERM

# Run the main loop
main "$@"
