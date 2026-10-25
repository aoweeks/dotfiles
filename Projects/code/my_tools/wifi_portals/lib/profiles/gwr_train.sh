#!/usr/bin/env bash
# ============================================================================
# Profile: GWR On-Board Train WiFi
# ============================================================================

PROFILE_NAME="GWR WiFi"
PROFILE_SSIDS=("GWR WiFi")

GWR_TRAIN_DOMAIN="gwr.passengerwifi.com"
GWR_TRAIN_URL="http://${GWR_TRAIN_DOMAIN}/"

# Returns 0 if portal is active (needs auth), 1 if internet is working, 2 if signal dropout
profile_is_portal_active() {
    check_internet_generic
    local status=$?
    if [[ "${status}" -eq 0 ]]; then
        return 1 # Internet is working (no portal)
    elif [[ "${status}" -eq 1 ]]; then
        return 0 # Internet is blocked (portal active)
    else
        return 2 # Network/Signal failure
    fi
}

profile_authenticate() {
    local iface cookie_file
    iface="$(get_wifi_interface)"
    cookie_file="/tmp/gwr_train_cookies_${$}.txt"
    rm -f "${cookie_file}"

    log "[${PROFILE_NAME}] Step 1: Fetching initial GWR train portal page..."
    local page1_html
    page1_html="$(curl -s -L -4 --max-time 10 --connect-timeout 5 \
        --interface "${iface}" \
        -c "${cookie_file}" "${GWR_TRAIN_URL}" 2>/dev/null)" || true

    if [[ -z "${page1_html}" ]]; then
        log "[${PROFILE_NAME}] ERROR: Failed to fetch portal page at ${GWR_TRAIN_URL}"
        rm -f "${cookie_file}"
        return 1
    fi

    # Extract hidden tokens (_token and _ceid)
    local token ceid
    token="$(echo "${page1_html}" | grep -zoP 'name="_token"[\s\S]*?value="\K[^"]+' 2>/dev/null | tr '\0' '\n' | head -n 1)" || true
    [[ -z "${token}" ]] && token="$(echo "${page1_html}" | grep -oP 'name="_token"\s+type="hidden"\s+value="\K[^"]+' | head -n 1)" || true

    ceid="$(echo "${page1_html}" | grep -zoP 'name="_ceid"[\s\S]*?value="\K[^"]+' 2>/dev/null | tr '\0' '\n' | head -n 1)" || true
    [[ -z "${ceid}" ]] && ceid="$(echo "${page1_html}" | grep -oP 'name="_ceid"\s+type="hidden"\s+value="\K[^"]+' | head -n 1)" || true

    log "[${PROFILE_NAME}] Tokens: _token=${token:-'(none)'}, _ceid=${ceid:-'1443'}"

    log "[${PROFILE_NAME}] Step 2: Submitting terms acceptance..."
    local step1_code
    step1_code="$(curl -s -o /dev/null -w '%{http_code}' \
        --max-time 10 --connect-timeout 5 \
        --interface "${iface}" \
        -b "${cookie_file}" -c "${cookie_file}" \
        -X POST "${GWR_TRAIN_URL}login.php" \
        -H "Host: ${GWR_TRAIN_DOMAIN}" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -H "Referer: ${GWR_TRAIN_URL}" \
        -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64; rv:137.0) Gecko/20100101 Firefox/137.0" \
        -d "_token=${token}&_ceid=${ceid:-1443}&form_type=registration&terms=1&lang=" \
        2>/dev/null)" || true

    log "[${PROFILE_NAME}] Step 2 response code: ${step1_code}"
    sleep 1

    log "[${PROFILE_NAME}] Step 3: Accessing confirmation / secondary page..."
    local page2_html
    page2_html="$(curl -s -L -4 --max-time 10 --connect-timeout 5 \
        --interface "${iface}" \
        -b "${cookie_file}" -c "${cookie_file}" "${GWR_TRAIN_URL}" 2>/dev/null)" || true

    local page2_action
    page2_action="$(echo "${page2_html}" | grep -zOP '<form[^>]+action="\K[^"]+' 2>/dev/null | tr -d '\0' | head -n 1)" || true

    if [[ -n "${page2_action}" && "${page2_action}" != "login.php"* ]]; then
        log "[${PROFILE_NAME}] Step 4: Submitting secondary form to ${page2_action}..."
        curl -s -o /dev/null --max-time 10 --connect-timeout 5 \
            --interface "${iface}" \
            -b "${cookie_file}" -c "${cookie_file}" \
            -X POST "${GWR_TRAIN_URL}${page2_action#/}" \
            -H "Referer: ${GWR_TRAIN_URL}" \
            -d "terms=1&accept=Access+Now" \
            2>/dev/null || true
    fi

    rm -f "${cookie_file}"
    sleep 2
    return 0
}
