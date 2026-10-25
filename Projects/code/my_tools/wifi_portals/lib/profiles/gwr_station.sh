#!/usr/bin/env bash
# ============================================================================
# Profile: GWR Station WiFi (Placeholder for future station portal)
# ============================================================================

PROFILE_NAME="GWR Station WiFi"
PROFILE_SSIDS=("GWR Station WiFi" "GWR_Station_WiFi")

# Returns 0 if portal is active (needs auth), 1 if internet is working
profile_is_portal_active() {
    # Check internet or station portal endpoint
    ! check_internet_generic
}

profile_authenticate() {
    log "[${PROFILE_NAME}] Taking a snapshot of the captive portal for later analysis..."
    curl -s -L "http://www.msftconnecttest.com/connecttest.txt" > "/tmp/gwr_station_portal_snapshot.html"
    log "[${PROFILE_NAME}] Snapshot saved to /tmp/gwr_station_portal_snapshot.html"
    log "[${PROFILE_NAME}] Warning: Profile placeholder - update authentication flow once station portal URL is inspected."
    return 1 # Return 1 so it doesn't falsely report success
}
