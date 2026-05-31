#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SYSTEMD_SERVICES=(
  ecoconnect-backend
  ecoconnect-detect
  ecoconnect-cam
  ecoconnect-ir
  ecoconnect-network
  ecoconnect-frontend
  ecoconnect-detector
)

REMOVE_DEPS=1
REINSTALL_DEPS=0

usage() {
  cat <<'EOF'
Usage: ./cleanup-systemd-installs.sh [options]

Options:
  --no-deps       Skip removal of local Node dependency installs
  --reinstall     Reinstall backend and frontend dependencies after cleanup
  -h, --help      Show this help message

This script stops, disables, and removes ecoconnect systemd units, reloads systemd,
cleans local dependency installs, and optionally reinstalls backend/frontend deps.
EOF
}

ensure_linux() {
  if [[ "$(uname -s)" != "Linux" ]]; then
    echo "[ERROR] This cleanup script only supports Linux/systemd."
    exit 1
  fi
}

ensure_command() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "[ERROR] Required command not found: $cmd"
    exit 1
  fi
}

ensure_sudo_access() {
  if ! command -v sudo >/dev/null 2>&1; then
    echo "[ERROR] sudo is required for systemd cleanup."
    exit 1
  fi

  if ! sudo -v >/dev/null 2>&1; then
    echo "[ERROR] Unable to validate sudo access."
    exit 1
  fi
}

stop_and_disable_services() {
  echo "[STEP] Stopping and disabling ecoconnect systemd services"

  for service in "${SYSTEMD_SERVICES[@]}"; do
    echo "[INFO] Stopping and disabling: $service"
    sudo systemctl stop "${service}.service" >/dev/null 2>&1 || true
    sudo systemctl disable "${service}.service" >/dev/null 2>&1 || true
  done
}

remove_unit_files() {
  echo "[STEP] Removing installed ecoconnect systemd unit files"
  sudo rm -f /etc/systemd/system/ecoconnect-*.service
  sudo rm -f /etc/systemd/system/multi-user.target.wants/ecoconnect-*.service
}

reload_systemd() {
  echo "[STEP] Reloading systemd daemon and clearing failed state"
  sudo systemctl daemon-reload >/dev/null 2>&1 || true
  sudo systemctl reset-failed >/dev/null 2>&1 || true
}

cleanup_node_modules() {
  if [[ "$REMOVE_DEPS" -eq 0 ]]; then
    echo "[INFO] Skipping local dependency cleanup"
    return
  fi

  echo "[STEP] Removing local Node dependency installs"
  rm -rf "$ROOT_DIR/apps/backend/node_modules"
  rm -rf "$ROOT_DIR/apps/frontend/node_modules"
  rm -rf "$ROOT_DIR/apps/backend/.pnpm-store"
  rm -rf "$ROOT_DIR/apps/frontend/.pnpm-store"
}

reinstall_dependencies() {
  if [[ "$REINSTALL_DEPS" -eq 0 ]]; then
    return
  fi

  ensure_command pnpm

  echo "[STEP] Reinstalling backend dependencies"
  (cd "$ROOT_DIR/apps/backend" && pnpm install)

  echo "[STEP] Reinstalling frontend dependencies"
  (cd "$ROOT_DIR/apps/frontend" && pnpm install)
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-deps)
      REMOVE_DEPS=0
      shift
      ;;
    --reinstall)
      REINSTALL_DEPS=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[ERROR] Unknown option: $1"
      usage
      exit 1
      ;;
  esac
done

ensure_linux
ensure_command systemctl
ensure_sudo_access

stop_and_disable_services
remove_unit_files
reload_systemd
cleanup_node_modules
reinstall_dependencies

echo "[SUCCESS] Systemd cleanup complete."
if [[ "$REINSTALL_DEPS" -eq 1 ]]; then
  echo "[SUCCESS] Dependencies reinstalled."
fi
