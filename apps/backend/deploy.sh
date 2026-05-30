#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-dev}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

if [[ ! -f "package.json" ]]; then
  echo "[ERROR] package.json not found. Run this script from ecoconnect-backend root."
  exit 1
fi

require_runtime() {
  if ! command -v node >/dev/null 2>&1; then
    echo "[ERROR] Node.js is not installed. Install Node.js v18+ first."
    exit 1
  fi

  if ! command -v pnpm >/dev/null 2>&1; then
    echo "[ERROR] pnpm is not installed. Install via: npm i -g pnpm"
    exit 1
  fi
}

ensure_env() {
  if [[ ! -f ".env" ]]; then
    echo "[STEP] Creating .env from .env.example"
    cp .env.example .env
    echo "[WARN] .env created. Please review values before production use."
  fi
}

install_deps() {
  echo "[STEP] Installing dependencies"
  pnpm install
}

run_dev() {
  local pid_file=".backend-dev.pid"
  local log_file="backend-dev.log"

  if [[ -f "$pid_file" ]]; then
    local existing_pid
    existing_pid="$(cat "$pid_file")"
    if [[ -n "$existing_pid" ]] && kill -0 "$existing_pid" >/dev/null 2>&1; then
      echo "[INFO] Backend dev server is already running in background (PID: $existing_pid)."
      echo "[INFO] Log file: $ROOT_DIR/$log_file"
      return
    fi

    echo "[WARN] Removing stale PID file: $pid_file"
    rm -f "$pid_file"
  fi

  echo "[STEP] Starting backend in dev mode (background)"
  nohup pnpm run dev >"$log_file" 2>&1 &
  local pid=$!
  echo "$pid" > "$pid_file"

  echo "[INFO] Backend started in background."
  echo "[INFO] PID: $pid"
  echo "[INFO] Logs: $ROOT_DIR/$log_file"
  echo "[INFO] To stop: kill $pid && rm -f $ROOT_DIR/$pid_file"
}

deploy_systemd() {
  if [[ "$(uname -s)" != "Linux" ]]; then
    echo "[ERROR] systemd deployment is supported on Linux only."
    exit 1
  fi

  if ! command -v systemctl >/dev/null 2>&1; then
    echo "[ERROR] systemctl not found."
    exit 1
  fi

  echo "[STEP] Installing systemd units"
  sudo cp deploy/systemd/ecoconnect-backend.service /etc/systemd/system/
  sudo cp deploy/systemd/ecoconnect-detector.service /etc/systemd/system/

  echo "[STEP] Reloading and enabling services"
  sudo systemctl daemon-reload
  sudo systemctl enable ecoconnect-backend
  sudo systemctl enable ecoconnect-detector

  echo "[STEP] Restarting services"
  sudo systemctl restart ecoconnect-backend
  sudo systemctl restart ecoconnect-detector

  echo "[STEP] Service status"
  sudo systemctl --no-pager --full status ecoconnect-backend || true
  sudo systemctl --no-pager --full status ecoconnect-detector || true
}

usage() {
  cat <<'EOF'
Usage:
  ./deploy.sh dev
  ./deploy.sh prod

Modes:
  dev   Install deps, ensure .env, and run pnpm run dev in background
  prod  Install deps, ensure .env, and deploy/restart systemd units (Linux)
EOF
}

case "$MODE" in
  dev)
    require_runtime
    ensure_env
    install_deps
    run_dev
    ;;
  prod)
    require_runtime
    ensure_env
    install_deps
    deploy_systemd
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    echo "[ERROR] Unknown mode: $MODE"
    usage
    exit 1
    ;;
esac
