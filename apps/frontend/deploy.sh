#!/usr/bin/env bash
set -euo pipefail

WEB_ROOT="${WEB_ROOT:-/var/www/html}"
SITE_URL="${SITE_URL:-http://10.42.0.1/}"
KIOSK_URL="${KIOSK_URL:-${SITE_URL%/}/kiosk}"
AUTO_OPEN_KIOSK="${AUTO_OPEN_KIOSK:-1}"
KIOSK_KILL_EXISTING="${KIOSK_KILL_EXISTING:-1}"
KIOSK_BROWSER="${KIOSK_BROWSER:-}"
KIOSK_DISPLAY="${KIOSK_DISPLAY:-:0}"

usage() {
  cat <<'EOF'
Usage:
  ./deploy.sh

Optional environment variables:
  WEB_ROOT=/var/www/html    Nginx web root target path
  SITE_URL=http://10.42.0.1/  URL to print after deploy
  KIOSK_URL=http://10.42.0.1/kiosk  Kiosk URL to launch in fullscreen browser
  AUTO_OPEN_KIOSK=1         Auto-open fullscreen browser to KIOSK_URL after deploy
  KIOSK_KILL_EXISTING=1     Kill existing kiosk browser processes before launch
  KIOSK_BROWSER=chromium-browser  Optional explicit browser binary
  KIOSK_DISPLAY=:0          X display to use when DISPLAY is not already set
EOF
}

stop_existing_kiosk_browser() {
  local browser_bin="$1"

  if [[ "${KIOSK_KILL_EXISTING}" != "1" ]]; then
    echo "[INFO] KIOSK_KILL_EXISTING disabled; skipping browser cleanup"
    return 0
  fi

  echo "[STEP] Stopping existing kiosk browser processes (if any)"

  if [[ "$browser_bin" == "firefox" ]]; then
    pkill -f "firefox.*--kiosk" >/dev/null 2>&1 || true
    return 0
  fi

  pkill -f "chromium-browser.*--kiosk" >/dev/null 2>&1 || true
  pkill -f "chromium.*--kiosk" >/dev/null 2>&1 || true
  pkill -f "google-chrome.*--kiosk" >/dev/null 2>&1 || true
}

launch_kiosk_browser() {
  local target_url="$1"
  local browser_bin="${KIOSK_BROWSER}"

  if [[ "${AUTO_OPEN_KIOSK}" != "1" ]]; then
    echo "[INFO] AUTO_OPEN_KIOSK disabled; skipping browser launch"
    return 0
  fi

  if [[ -z "${DISPLAY:-}" ]]; then
    export DISPLAY="$KIOSK_DISPLAY"
    echo "[INFO] DISPLAY not set; using DISPLAY=$DISPLAY"
  fi

  if [[ -z "$browser_bin" ]]; then
    if command -v chromium-browser >/dev/null 2>&1; then
      browser_bin="chromium-browser"
    elif command -v chromium >/dev/null 2>&1; then
      browser_bin="chromium"
    elif command -v google-chrome >/dev/null 2>&1; then
      browser_bin="google-chrome"
    elif command -v firefox >/dev/null 2>&1; then
      browser_bin="firefox"
    fi
  fi

  if [[ -z "$browser_bin" ]]; then
    echo "[WARN] No supported browser found (chromium-browser/chromium/google-chrome/firefox); skipping kiosk launch"
    return 0
  fi

  stop_existing_kiosk_browser "$browser_bin"

  echo "[STEP] Launching fullscreen browser: $browser_bin -> $target_url"

  if [[ "$browser_bin" == "firefox" ]]; then
    nohup "$browser_bin" --kiosk "$target_url" >/tmp/ecoconnect-kiosk.log 2>&1 &
  else
    nohup "$browser_bin" \
      --kiosk \
      --incognito \
      --noerrdialogs \
      --disable-session-crashed-bubble \
      --check-for-update-interval=31536000 \
      "$target_url" >/tmp/ecoconnect-kiosk.log 2>&1 &
  fi
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" || "${1:-}" == "help" ]]; then
  usage
  exit 0
fi

echo "[INFO] Starting EcoConnect frontend deploy"

if [[ ! -f "package.json" ]]; then
  echo "[ERROR] package.json not found. Run this script from eco-connect root."
  exit 1
fi

if ! command -v pnpm >/dev/null 2>&1; then
  echo "[ERROR] pnpm is not installed. Install via: npm i -g pnpm"
  exit 1
fi

if ! command -v systemctl >/dev/null 2>&1; then
  echo "[ERROR] systemctl not found. This script expects a Linux host with systemd + nginx."
  exit 1
fi

if [[ ! -f ".env" ]]; then
  if [[ -f ".env.example" ]]; then
    echo "[STEP] Creating .env from .env.example"
    cp .env.example .env
  else
    echo "[WARN] .env missing and .env.example not found; continuing without creating .env"
  fi
fi

echo "[STEP] Installing dependencies"
pnpm install

echo "[STEP] Building project"
pnpm run build

if [[ ! -d "dist" ]]; then
  echo "[ERROR] Build failed: dist folder not found"
  exit 1
fi

echo "[STEP] Clearing old Nginx files"
sudo mkdir -p "$WEB_ROOT"
sudo rm -rf "$WEB_ROOT"/*

echo "[STEP] Copying new build"
if command -v rsync >/dev/null 2>&1; then
  sudo rsync -av --delete dist/ "$WEB_ROOT"/
else
  sudo cp -r dist/* "$WEB_ROOT"/
fi

echo "[STEP] Fixing permissions"
sudo chown -R www-data:www-data "$WEB_ROOT"
sudo chmod -R 755 "$WEB_ROOT"

echo "[STEP] Restarting Nginx"
sudo systemctl restart nginx

launch_kiosk_browser "$KIOSK_URL"

echo "[SUCCESS] Deploy complete"
echo "[INFO] Open: $SITE_URL"
echo "[INFO] Kiosk: $KIOSK_URL"
