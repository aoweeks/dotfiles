#!/usr/bin/env bash
# ============================================================================
# Profile: Waterstones WiFi
# ============================================================================

PROFILE_NAME="Waterstones WiFi"
PROFILE_SSIDS=("_Waterstones WiFi")

WATERSTONES_PORTAL_IP="192.168.1.1"
WATERSTONES_CONTROLLER_URL="http://10.255.76.251:8002/index.php?zone=waterstones"
WATERSTONES_AUTH_USER="user1"
WATERSTONES_AUTH_PASS="user1"
WATERSTONES_ZONE="waterstones"
WATERSTONES_REDIR_URL="http://wifi.waterstones.com"

# Returns 0 if portal is active (needs auth), 1 if internet is working,
# 2 if the network timed out / dropped packets (not a portal problem).
# Uses the Microsoft connecttest URL rather than the portal page itself,
# because the Aruba portal at 192.168.1.1 always serves the login HTML
# regardless of auth status (auth works by MAC whitelisting).
profile_is_portal_active() {
    local status=0
    check_internet_generic || status=$?
    if [[ "${status}" -eq 0 ]]; then
        return 1 # Internet is working (no portal)
    elif [[ "${status}" -eq 1 ]]; then
        return 0 # Portal is intercepting
    else
        return 2 # Timeout / packet loss
    fi
}

profile_authenticate() {
    local iface ip mac devicetype="desktop"
    iface="$(get_wifi_interface)"

    ip="$(get_local_ip "${iface}")" || ip=""
    mac="$(get_mac "${iface}")" || mac=""

    log "[${PROFILE_NAME}] Using interface: ${iface}, IP: ${ip}, MAC: ${mac}"

    log "[${PROFILE_NAME}] Step 1: Submitting terms acceptance to portal..."
    local step1_code
    step1_code="$(curl -s -o /dev/null -w '%{http_code}' \
        --max-time 10 --connect-timeout 5 \
        --interface "${iface}" \
        -X POST "http://${WATERSTONES_PORTAL_IP}/index.php" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -H "Referer: http://${WATERSTONES_PORTAL_IP}/" \
        -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64; rv:137.0) Gecko/20100101 Firefox/137.0" \
        -d "aup=on&auth_user=${WATERSTONES_AUTH_USER}&auth_pass=${WATERSTONES_AUTH_PASS}&zone=${WATERSTONES_ZONE}&devicetype=${devicetype}&ipaddress=${ip}&user_mac=${mac}&redirurl=${WATERSTONES_REDIR_URL}&accept=Connect" \
        2>/dev/null)" || true

    log "[${PROFILE_NAME}] Step 1 response code: ${step1_code}"
    sleep 1

    log "[${PROFILE_NAME}] Step 2: Authenticating with Aruba controller..."
    local step2_code
    step2_code="$(curl -s -o /dev/null -w '%{http_code}' \
        --max-time 10 --connect-timeout 5 \
        --interface "${iface}" \
        -X POST "${WATERSTONES_CONTROLLER_URL}" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -H "Referer: http://${WATERSTONES_PORTAL_IP}/authenticate.php" \
        -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64; rv:137.0) Gecko/20100101 Firefox/137.0" \
        -d "auth_user=${WATERSTONES_AUTH_USER}&auth_pass=${WATERSTONES_AUTH_PASS}&redirurl=${WATERSTONES_REDIR_URL}&zone=${WATERSTONES_ZONE}&accept=Start+Browsing" \
        2>/dev/null)" || true

    log "[${PROFILE_NAME}] Step 2 response code: ${step2_code}"
    sleep 2
    return 0
}
