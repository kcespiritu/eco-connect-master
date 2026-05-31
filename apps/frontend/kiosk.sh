#!/usr/bin/env bash
set -euo pipefail

KIOSK_URL="${KIOSK_URL:-http://10.42.0.1/kiosk}"
KIOSK_DISPLAY="${KIOSK_DISPLAY:-:0}"
KIOSK_BROWSER="${KIOSK_BROWSER:-}"
KIOSK_BROWSER_EXTRA_ARGS="${KIOSK_BROWSER_EXTRA_ARGS:-}"
APP_USER="${APP_USER:-${USER:-thesis}}"

if [[ -z "${DISPLAY:-}" ]]; then
  export DISPLAY="$KIOSK_DISPLAY"
fi

if [[ -z "${XAUTHORITY:-}" ]]; then
  user_home="$(getent passwd "$APP_USER" | cut -d: -f6 || true)"
  if [[ -z "$user_home" ]]; then
    user_home="$HOME"
  fi
  export XAUTHORITY="$user_home/.Xauthority"
fi

resolve_browser() {
  if [[ -n "$KIOSK_BROWSER" ]]; then
    if command -v "$KIOSK_BROWSER" >/dev/null 2>&1; then
      echo "$KIOSK_BROWSER"
      return 0
    fi

    echo "[ERROR] KIOSK_BROWSER is set but not found: $KIOSK_BROWSER"
    exit 1
  fi

  if command -v chromium-browser >/dev/null 2>&1; then
    echo "chromium-browser"
    return 0
  fi

  if command -v chromium >/dev/null 2>&1; then
    echo "chromium"
    return 0
  fi

  if command -v google-chrome >/dev/null 2>&1; then
    echo "google-chrome"
    return 0
  fi

  if command -v firefox >/dev/null 2>&1; then
    echo "firefox"
    return 0
  fi

  echo "[ERROR] No supported browser found (chromium-browser/chromium/google-chrome/firefox)"
  exit 1
}

wait_for_x_server() {
  local display_num="${DISPLAY#:}"
  display_num="${display_num%%.*}"
  local socket_path="/tmp/.X11-unix/X${display_num}"

  for _ in $(seq 1 90); do
    if [[ -S "$socket_path" ]]; then
      return 0
    fi
    sleep 1
  done

  echo "[ERROR] X server socket not ready: $socket_path"
  exit 1
}

wait_for_xauth() {
  for _ in $(seq 1 90); do
    if [[ -f "$XAUTHORITY" ]]; then
      return 0
    fi
    sleep 1
  done

  echo "[WARN] XAUTHORITY file not found after wait: $XAUTHORITY"
}

browser_bin="$(resolve_browser)"

echo "[INFO] Starting kiosk browser"
echo "[INFO] URL: $KIOSK_URL"
echo "[INFO] DISPLAY: $DISPLAY"
echo "[INFO] XAUTHORITY: $XAUTHORITY"
echo "[INFO] Browser: $browser_bin"

wait_for_x_server
wait_for_xauth

if [[ "$browser_bin" == "firefox" ]]; then
  exec "$browser_bin" --kiosk "$KIOSK_URL"
fi

if [[ -n "$KIOSK_BROWSER_EXTRA_ARGS" ]]; then
  # shellcheck disable=SC2206
  extra_args=( $KIOSK_BROWSER_EXTRA_ARGS )
else
  extra_args=()
fi

exec "$browser_bin" \
  --kiosk \
  --incognito \
  --noerrdialogs \
  --disable-session-crashed-bubble \
  --check-for-update-interval=31536000 \
  "${extra_args[@]}" \
  "$KIOSK_URL"