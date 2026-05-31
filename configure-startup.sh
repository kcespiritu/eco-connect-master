#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_USER="${APP_USER:-${SUDO_USER:-$USER}}"
STARTUP_ENV_FILE="${STARTUP_ENV_FILE:-/etc/default/ecoconnect}"
PERSIST_BASE_DIR="${PERSIST_BASE_DIR:-/var/lib/ecoconnect}"
PERSIST_RUNTIME_DIR="${PERSIST_RUNTIME_DIR:-${PERSIST_BASE_DIR}/runtime}"
PERSIST_DB_PATH="${PERSIST_DB_PATH:-${PERSIST_BASE_DIR}/ecoconnect.db}"
PERSIST_FRAME_PATH="${PERSIST_FRAME_PATH:-${PERSIST_BASE_DIR}/frame.jpg}"
PERSIST_DETECT_OUTPUT_DIR="${PERSIST_DETECT_OUTPUT_DIR:-${PERSIST_BASE_DIR}/output_frames}"

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "[ERROR] Startup auto-configuration currently supports Linux/systemd only."
  exit 1
fi

if ! command -v systemctl >/dev/null 2>&1; then
  echo "[ERROR] systemctl not found."
  exit 1
fi

if ! command -v sudo >/dev/null 2>&1; then
  echo "[ERROR] sudo is required to install systemd units."
  exit 1
fi

install_unit() {
  local unit_name="$1"
  local unit_body="$2"

  echo "[STEP] Installing ${unit_name}"
  printf "%s\n" "$unit_body" | sudo tee "/etc/systemd/system/${unit_name}" >/dev/null
}

ensure_env_key() {
  local file_path="$1"
  local key="$2"
  local value="$3"

  if sudo grep -q "^${key}=" "$file_path"; then
    return 0
  fi

  echo "[STEP] Adding ${key} to ${file_path}"
  echo "${key}=${value}" | sudo tee -a "$file_path" >/dev/null
}

network_unit="[Unit]
Description=EcoConnect Network Init
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=${ROOT_DIR}
ExecStart=/usr/bin/env bash ${ROOT_DIR}/hardware/network.sh

[Install]
WantedBy=multi-user.target"

ir_unit="[Unit]
Description=EcoConnect IR Service
After=ecoconnect-network.service
Requires=ecoconnect-network.service

[Service]
Type=simple
WorkingDirectory=${ROOT_DIR}
ExecStart=/usr/bin/env python3 ${ROOT_DIR}/hardware/ir.py
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target"

cam_unit="[Unit]
Description=EcoConnect Camera Service
After=ecoconnect-network.service
Requires=ecoconnect-network.service

[Service]
Type=simple
WorkingDirectory=${ROOT_DIR}
ExecStart=/usr/bin/env python3 ${ROOT_DIR}/hardware/cam.py
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target"

detect_unit="[Unit]
Description=EcoConnect Detect Service
After=ecoconnect-network.service
Requires=ecoconnect-network.service

[Service]
Type=simple
WorkingDirectory=${ROOT_DIR}
EnvironmentFile=-${STARTUP_ENV_FILE}
ExecStart=/bin/bash -lc '\"\${DETECT_PYTHON:-/usr/bin/python3}\" ${ROOT_DIR}/hardware/detect.py'
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target"

backend_unit="[Unit]
Description=EcoConnect Backend API
After=ecoconnect-ir.service ecoconnect-cam.service ecoconnect-detect.service
Requires=ecoconnect-ir.service ecoconnect-cam.service ecoconnect-detect.service

[Service]
Type=simple
User=${APP_USER}
WorkingDirectory=${ROOT_DIR}/apps/backend
Environment=NODE_ENV=production
EnvironmentFile=-${STARTUP_ENV_FILE}
EnvironmentFile=-${ROOT_DIR}/apps/backend/.env
ExecStart=/usr/bin/env node src/server.js
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target"

frontend_unit="[Unit]
Description=EcoConnect Frontend Runtime (Nginx)
After=ecoconnect-backend.service nginx.service
Wants=nginx.service
Requires=ecoconnect-backend.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/env bash -lc 'systemctl start nginx'

[Install]
WantedBy=multi-user.target"

install_unit "ecoconnect-network.service" "$network_unit"
install_unit "ecoconnect-ir.service" "$ir_unit"
install_unit "ecoconnect-cam.service" "$cam_unit"
install_unit "ecoconnect-detect.service" "$detect_unit"
install_unit "ecoconnect-backend.service" "$backend_unit"
install_unit "ecoconnect-frontend.service" "$frontend_unit"

echo "[STEP] Ensuring persistent directories"
sudo mkdir -p "$PERSIST_BASE_DIR" "$PERSIST_RUNTIME_DIR" "$PERSIST_DETECT_OUTPUT_DIR"

if [[ ! -f "$STARTUP_ENV_FILE" ]]; then
  echo "[STEP] Creating startup env file at ${STARTUP_ENV_FILE}"
  sudo tee "$STARTUP_ENV_FILE" >/dev/null <<'EOF'
# Optional override for detect.py interpreter (venv)
# Example:
# DETECT_PYTHON=/opt/ecoconnect/.venv/bin/python
DETECT_PYTHON=

# Persistent data paths
NETWORK_TMP_DIR=/var/lib/ecoconnect/runtime
SHARED_FRAME_PATH=/var/lib/ecoconnect/frame.jpg
DETECT_OUTPUT_DIR=/var/lib/ecoconnect/output_frames
ECOCONNECT_DB_PATH=/var/lib/ecoconnect/ecoconnect.db
EOF
fi

ensure_env_key "$STARTUP_ENV_FILE" "NETWORK_TMP_DIR" "/var/lib/ecoconnect/runtime"
ensure_env_key "$STARTUP_ENV_FILE" "SHARED_FRAME_PATH" "/var/lib/ecoconnect/frame.jpg"
ensure_env_key "$STARTUP_ENV_FILE" "DETECT_OUTPUT_DIR" "/var/lib/ecoconnect/output_frames"
ensure_env_key "$STARTUP_ENV_FILE" "ECOCONNECT_DB_PATH" "/var/lib/ecoconnect/ecoconnect.db"

echo "[STEP] Reloading systemd daemon"
sudo systemctl daemon-reload

if systemctl list-unit-files | grep -q '^ecoconnect-detector\.service'; then
  echo "[STEP] Disabling legacy ecoconnect-detector.service"
  sudo systemctl disable --now ecoconnect-detector.service || true
fi

echo "[STEP] Enabling services at boot"
sudo systemctl enable ecoconnect-network.service ecoconnect-ir.service ecoconnect-cam.service ecoconnect-detect.service ecoconnect-backend.service ecoconnect-frontend.service

echo "[STEP] Starting services now"
sudo systemctl restart ecoconnect-network.service
sudo systemctl restart ecoconnect-ir.service
sudo systemctl restart ecoconnect-cam.service
sudo systemctl restart ecoconnect-detect.service
sudo systemctl restart ecoconnect-backend.service
sudo systemctl restart ecoconnect-frontend.service

echo "[SUCCESS] Startup configured. Services will auto-run on reboot."
echo "[INFO] Service status overview:"
sudo systemctl --no-pager --full status ecoconnect-network.service || true
sudo systemctl --no-pager --full status ecoconnect-ir.service || true
sudo systemctl --no-pager --full status ecoconnect-cam.service || true
sudo systemctl --no-pager --full status ecoconnect-detect.service || true
sudo systemctl --no-pager --full status ecoconnect-backend.service || true
sudo systemctl --no-pager --full status ecoconnect-frontend.service || true
