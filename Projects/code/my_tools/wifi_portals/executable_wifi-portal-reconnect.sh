#!/usr/bin/env bash
# ============================================================================
# WiFi Portal Auto-Reconnect Framework — Main Engine Daemon
# ============================================================================
# Automatically detects current WiFi network, matches it to registered
# captive portal profiles (e.g. Waterstones, GWR Train, GWR Station),
# monitors connectivity, and auto-reauthenticates on session timeout or wake.
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"
PROFILES_DIR="${LIB_DIR}/profiles"

# Load core functions
if [[ -f "${LIB_DIR}/core.sh" ]]; then
    source "${LIB_DIR}/core.sh"
else
    echo "ERROR: ${LIB_DIR}/core.sh not found!" >&2
    exit 1
fi

# Load all profiles into memory
declare -A SSID_TO_PROFILE_FILE

load_profiles() {
    local profile_file
    for profile_file in "${PROFILES_DIR}"/*.sh; do
        [[ -f "${profile_file}" ]] || continue

        # Clear variables before sourcing
        PROFILE_NAME=""
        PROFILE_SSIDS=()

        source "${profile_file}"

        if [[ -n "${PROFILE_NAME}" && ${#PROFILE_SSIDS[@]} -gt 0 ]]; then
            log "Loaded profile: '${PROFILE_NAME}' for SSIDs: ${PROFILE_SSIDS[*]}"
            for ssid in "${PROFILE_SSIDS[@]}"; do
                SSID_TO_PROFILE_FILE["${ssid}"]="${profile_file}"
            done
        fi
    done
}

# Retry & interval settings
CHECK_INTERVAL=5
MAX_RETRIES=3
RETRY_DELAY=3

# ---------------------------------------------------------------------------
# Core Reconnection Attempt Engine
# ---------------------------------------------------------------------------
attempt_reconnect_for_profile() {
    local prof_name="${1}"
    local suppress_notifications="${2:-0}"
    local attempt

    local signal signal_desc
    signal="$(get_signal_strength)" || signal=""
    signal_desc="$(classify_signal "${signal:-0}")"

    # If signal is very weak or absent, skip auth attempts entirely —
    # no point POSTing forms if the radio link is barely there.
    if [[ -n "${signal}" && "${signal}" -lt 10 ]]; then
        log "[${prof_name}] Signal too weak to attempt auth: ${signal_desc}"
        if [[ "${suppress_notifications}" -eq 0 ]]; then
            notify "low" \
                "📶 Signal Lost — ${prof_name}" \
                "WiFi signal is ${signal_desc}.\nSkipping reconnection until signal improves." \
                "network-wireless-20"
        fi
        return 1
    fi

    if [[ "${suppress_notifications}" -eq 0 ]]; then
        notify "critical" \
            "⚠️ Captive Portal Detected" \
            "${prof_name} session expired (signal: ${signal_desc}).\nAttempting automatic reconnection..." \
            "network-wireless-100-locked"
    fi

    log "[${prof_name}] Starting automatic reconnection flow (signal: ${signal_desc})"

    for attempt in $(seq 1 "${MAX_RETRIES}"); do
        log "[${prof_name}] Reconnection attempt ${attempt}/${MAX_RETRIES}"

        if profile_authenticate; then
            sleep 1
            local status=0
            profile_is_portal_active || status=$?
            if [[ "${status}" -eq 1 ]]; then
                log "[${prof_name}] SUCCESS: Internet access restored on attempt ${attempt}"
                # Always notify on success, even if failures are suppressed, so user knows it's back
                notify "normal" \
                    "✅ WiFi Reconnected" \
                    "Successfully re-authenticated to ${prof_name}." \
                    "network-wireless-100"
                return 0
            elif [[ "${status}" -eq 2 ]]; then
                log "[${prof_name}] Signal dropout after authentication, retrying..."
            else
                log "[${prof_name}] Auth completed but portal still active, retrying..."
            fi
        fi

        if [[ "${attempt}" -lt "${MAX_RETRIES}" ]]; then
            sleep "${RETRY_DELAY}"
        fi
    done

    # Re-check signal after all attempts failed to give a useful diagnosis
    signal="$(get_signal_strength)" || signal=""
    signal_desc="$(classify_signal "${signal:-0}")"

    if [[ "${suppress_notifications}" -eq 0 ]]; then
        if [[ -n "${signal}" && "${signal}" -lt 30 ]]; then
            log "[${prof_name}] FAILED: Reconnection failed — likely due to weak signal: ${signal_desc}"
            notify "critical" \
                "📶 Reconnection Failed — Weak Signal" \
                "Could not re-authenticate to ${prof_name}.\nSignal is ${signal_desc}. Will retry when signal improves." \
                "network-wireless-disconnected"
        else
            log "[${prof_name}] FAILED: Could not restore internet after ${MAX_RETRIES} attempts (signal: ${signal_desc})"
            notify "critical" \
                "❌ Reconnection Failed" \
                "Could not re-authenticate to ${prof_name} after ${MAX_RETRIES} attempts.\nSignal was ${signal_desc} — portal may require manual login." \
                "network-wireless-disconnected"
        fi
    else
        log "[${prof_name}] FAILED: Reconnection failed again (signal: ${signal_desc}). Notifications suppressed."
    fi
    return 1
}

# ---------------------------------------------------------------------------
# Main Daemon Loop
# ---------------------------------------------------------------------------
main() {
    load_profiles

    local iface
    iface="$(get_wifi_interface)"

    log "========================================="
    log "WiFi Portal Auto-Reconnect Daemon Started"
    log "Environment: Linux Desktop"
    log "WiFi Interface: ${iface}"
    log "Check Interval: ${CHECK_INTERVAL}s"
    log "========================================="

    notify "low" \
        "🛜 WiFi Portal Monitor Active" \
        "Monitoring public WiFi connections on ${iface}." \
        "network-wireless-100"

    local consecutive_failures=0
    local failure_notified=0
    local last_connected_ssid=""
    local last_check_ts
    last_check_ts="$(date +%s)"

    while true; do
        local now elapsed
        now="$(date +%s)"
        elapsed=$((now - last_check_ts))

        # Sleep/wake detection
        local threshold=$((CHECK_INTERVAL * 3 + 15))
        if [[ "${elapsed}" -gt ${threshold} ]]; then
            log "Wake-from-sleep detected (${elapsed}s elapsed). Resetting failure states."
            failure_notified=0
            consecutive_failures=1
        fi
        last_check_ts="${now}"

        local current_ssid
        current_ssid="$(get_active_ssid)" || current_ssid=""

        if [[ -z "${current_ssid}" ]]; then
            # Network disconnected entirely
            if [[ -n "${last_connected_ssid}" ]]; then
                log "Network disconnected. Resetting failure states."
            fi
            consecutive_failures=0
            failure_notified=0
            last_connected_ssid=""
            sleep "${CHECK_INTERVAL}"
            continue
        fi

        # SSID changed or reconnected
        if [[ "${current_ssid}" != "${last_connected_ssid}" ]]; then
            if [[ -n "${last_connected_ssid}" ]]; then
                log "Connected to new SSID: '${current_ssid}'. Resetting failure states."
            fi
            failure_notified=0
            consecutive_failures=0
            last_connected_ssid="${current_ssid}"
        fi

        # Find matching profile file for active SSID
        local profile_file="${SSID_TO_PROFILE_FILE["${current_ssid}"]:-}"

        if [[ -z "${profile_file}" || ! -f "${profile_file}" ]]; then
            # Not connected to a managed portal WiFi network
            consecutive_failures=0
            failure_notified=0
            sleep "${CHECK_INTERVAL}"
            continue
        fi

        # Source the matching profile to expose its functions & variables
        source "${profile_file}"

        local portal_status=0
        profile_is_portal_active || portal_status=$?

        if [[ "${portal_status}" -eq 1 ]]; then
            if [[ "${consecutive_failures}" -gt 0 ]]; then
                log "[${PROFILE_NAME}] Connectivity confirmed working"
            fi
            consecutive_failures=0
            failure_notified=0
        elif [[ "${portal_status}" -eq 2 ]]; then
            local sig sig_desc
            sig="$(get_signal_strength)" || sig=""
            sig_desc="$(classify_signal "${sig:-0}")"
            log "[${PROFILE_NAME}] Signal dropout detected (signal: ${sig_desc}). Waiting for network..."
        else
            consecutive_failures=$((consecutive_failures + 1))

            local sig sig_desc
            sig="$(get_signal_strength)" || sig=""
            sig_desc="$(classify_signal "${sig:-0}")"
            log "[${PROFILE_NAME}] Internet check failed (${consecutive_failures} consecutive, signal: ${sig_desc})"

            if [[ "${consecutive_failures}" -ge 2 ]]; then
                if attempt_reconnect_for_profile "${PROFILE_NAME}" "${failure_notified}"; then
                    # Reconnect succeeded
                    consecutive_failures=0
                    failure_notified=0
                    last_check_ts="$(date +%s)" # Reset timer so we don't trigger wake-from-sleep logic
                else
                    # Reconnect failed. 
                    # Prime the pump so the very next loop iteration triggers another attempt.
                    consecutive_failures=1
                    failure_notified=1
                    last_check_ts="$(date +%s)"
                fi
            fi
        fi

        # Determine how long to wait before the next check.
        # If we are in a known failure state, poll faster (10 seconds).
        local sleep_time="${CHECK_INTERVAL}"
        if [[ "${failure_notified}" -eq 1 ]]; then
            sleep_time=10
        fi
        
        sleep "${sleep_time}"
    done
}

trap 'log "Shutting down..."; exit 0' SIGINT SIGTERM

main "$@"
