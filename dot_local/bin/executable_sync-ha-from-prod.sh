#!/usr/bin/env bash
set -euo pipefail

DEST="/opt/docker/homeassistant/config"
CONTAINER="homeassistant-sandbox"

LAN_IP="10.13.10.4"
TAILSCALE_IP="100.84.191.85"
RADICALE_TAILSCALE_IP="100.101.35.106"

cleanup() {
    echo "==> Ensuring sandbox container is running..."
    docker start "${CONTAINER}" >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "==> Stopping sandbox container for clean sync..."
docker stop "${CONTAINER}" >/dev/null 2>&1 || true

# 1. Detect whether we are on local LAN or remote via Tailscale
echo "==> Checking connection to production Home Assistant..."
if ssh -o ConnectTimeout=2 -o BatchMode=yes "root@${LAN_IP}" "true" 2>/dev/null; then
    TARGET_IP="${LAN_IP}"
    echo "    -> Connected via local home LAN (${TARGET_IP})"
elif ssh -o ConnectTimeout=4 -o BatchMode=yes "root@${TAILSCALE_IP}" "true" 2>/dev/null; then
    TARGET_IP="${TAILSCALE_IP}"
    echo "    -> Connected via Tailscale mesh tunnel (${TARGET_IP})"
else
    echo "[ERROR] Could not reach Home Assistant via LAN (${LAN_IP}) or Tailscale (${TAILSCALE_IP})."
    echo "Check if you are connected to the network or if Tailscale is running."
    exit 1
fi

echo "==> Streaming configuration from production (${TARGET_IP}) via tar..."
ssh "root@${TARGET_IP}" "tar -czf - \
  --exclude='home-assistant_v2.db*' \
  --exclude='*.log*' \
  --exclude='backups' \
  --exclude='.cloud' \
  --exclude='tts' \
  --exclude='__pycache__' \
  -C /config ." | tar -xzf - --no-same-owner -C "${DEST}/"

echo "==> Applying sandbox isolation whitelist to integrations..."
python3 - << PYEOF
import json
import os

# 1. Isolate Integrations
config_path = "${DEST}/.storage/core.config_entries"
if os.path.exists(config_path):
    with open(config_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    # ONLY these domains remain enabled in your sandbox.
    WHITELIST = {
        "caldav",
        "weather",
        "met",
        "met_office",
        "google_travel_time",
        "openpublictransport",
        "my_rail_commute",
        "todo",
        "local_todo",
        "calendar",
        "time_date",
        "sun",
        "conversation",
        "default_config",
        "frontend",
        "websocket_api",
        "http",
        "api",
        "system_health",
        "diagnostics",
        "hacs",
    }

    disabled_count = 0
    for entry in data.get("data", {}).get("entries", []):
        domain = entry.get("domain")
        title = entry.get("title", domain)

        # Ensure CalDAV points to Radicale's Tailscale IP (${RADICALE_TAILSCALE_IP})
        # This works both at home (direct p2p LAN) and when away from home!
        if domain == "caldav" and "data" in entry and "url" in entry["data"]:
            old_url = entry["data"]["url"]
            new_url = "http://${RADICALE_TAILSCALE_IP}:5232"
            if old_url != new_url:
                entry["data"]["url"] = new_url
                print(f"  [CalDAV] Re-pointed server URL to {new_url}")

        if domain not in WHITELIST:
            if entry.get("disabled_by") != "user":
                entry["disabled_by"] = "user"
                disabled_count += 1
                print(f"  [Sandbox Isolated] Disabled: {title} ({domain})")
        else:
            entry["disabled_by"] = None

    with open(config_path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)

    print(f"==> Isolation complete: {disabled_count} integrations safely disabled.")

# 2. Reset HTTP port to 8123 (production runs on port 80, which conflicts on laptop)
http_path = "${DEST}/.storage/http"
if os.path.exists(http_path):
    with open(http_path, "r", encoding="utf-8") as f:
        http_data = json.load(f)
    if "stable" in http_data.get("data", {}):
        http_data["data"]["stable"]["server_port"] = 8123
        print("  [Network] Set sandbox HTTP port to 8123 to avoid local port 80 collisions.")
    with open(http_path, "w", encoding="utf-8") as f:
        json.dump(http_data, f, indent=2)

PYEOF

echo "==> Restarting sandbox container..."
docker start "${CONTAINER}" >/dev/null 2>&1 || true

echo "==> Sandbox ready! Access http://localhost:8123"
