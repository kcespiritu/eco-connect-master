#!/usr/bin/env bash
set -euo pipefail

TARGET="${1:-all}"
MODE="${2:-prod}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$ROOT_DIR/apps/backend"
FRONTEND_DIR="$ROOT_DIR/apps/frontend"
HARDWARE_DIR="$ROOT_DIR/hardware"

BACKEND_SCRIPT="$BACKEND_DIR/deploy.sh"
FRONTEND_SCRIPT="$FRONTEND_DIR/deploy.sh"
NETWORK_SCRIPT="$HARDWARE_DIR/network.sh"
IR_SCRIPT="$HARDWARE_DIR/ir.py"
CAM_SCRIPT="$HARDWARE_DIR/cam.py"
DETECT_SCRIPT="$HARDWARE_DIR/detect.py"

DETECT_VENV_PATH="${DETECT_VENV_PATH:-}"
DETECT_PYTHON="${DETECT_PYTHON:-}"
HARDWARE_RUN_WITH_SUDO="${HARDWARE_RUN_WITH_SUDO:-1}"
MASTER_RUNTIME_DIR="${MASTER_RUNTIME_DIR:-$ROOT_DIR/.runtime}"
MASTER_LOG_DIR="${MASTER_LOG_DIR:-$ROOT_DIR/logs}"
STARTUP_SCRIPT="$ROOT_DIR/configure-startup.sh"

usage() {
	cat <<'EOF'
Usage:
	./deploy-master.sh [target] [mode]

Targets:
	all        Run hardware stack, then backend and frontend (default)
	hardware   Run hardware stack only
	backend    Deploy backend only
	frontend   Deploy frontend only
	install-startup  Install and enable systemd services for reboot persistence

Modes:
	prod       Backend: systemd deploy, Frontend: build + nginx deploy (default)
	dev        Backend: start dev server in background, Frontend: still does build + nginx deploy

Examples:
	./deploy-master.sh
	./deploy-master.sh all prod
	./deploy-master.sh backend dev
	./deploy-master.sh frontend prod

Notes:
	- Default flow for target=all:
		1) network.sh
		2) ir.py (background)
		3) cam.py (background)
		4) detect.py (background)
		5) backend deploy
		6) frontend deploy
	- Frontend deploy script currently has a single deploy flow (build + nginx restart).
	- Hardware process logs/pids default to:
		MASTER_LOG_DIR=$ROOT_DIR/logs
		MASTER_RUNTIME_DIR=$ROOT_DIR/.runtime
	- detect.py interpreter selection order:
		DETECT_PYTHON (if set) -> DETECT_VENV_PATH/bin/python -> python3 -> python
	- You can pass frontend env vars inline, e.g.:
			WEB_ROOT=/var/www/html SITE_URL=http://10.42.0.1/ ./deploy-master.sh frontend prod
	- Configure startup auto-run once:
			./deploy-master.sh install-startup
EOF
}

ensure_script_exists() {
	local path="$1"
	if [[ ! -f "$path" ]]; then
		echo "[ERROR] Missing script: $path"
		exit 1
	fi
}

ensure_dir_exists() {
	local path="$1"
	mkdir -p "$path"
}

resolve_detect_python() {
	if [[ -n "$DETECT_PYTHON" ]]; then
		echo "$DETECT_PYTHON"
		return 0
	fi

	if [[ -n "$DETECT_VENV_PATH" ]]; then
		if [[ -x "$DETECT_VENV_PATH/bin/python" ]]; then
			echo "$DETECT_VENV_PATH/bin/python"
			return 0
		fi

		echo "[ERROR] DETECT_VENV_PATH is set but python not found: $DETECT_VENV_PATH/bin/python"
		exit 1
	fi

	if command -v python3 >/dev/null 2>&1; then
		echo "python3"
		return 0
	fi

	if command -v python >/dev/null 2>&1; then
		echo "python"
		return 0
	fi

	echo "[ERROR] No Python interpreter found for detect.py"
	exit 1
}

start_managed_process() {
	local name="$1"
	shift

	ensure_dir_exists "$MASTER_RUNTIME_DIR"
	ensure_dir_exists "$MASTER_LOG_DIR"

	local pid_file="$MASTER_RUNTIME_DIR/${name}.pid"
	local log_file="$MASTER_LOG_DIR/${name}.log"

	if [[ -f "$pid_file" ]]; then
		local existing_pid
		existing_pid="$(cat "$pid_file")"
		if [[ -n "$existing_pid" ]] && kill -0 "$existing_pid" >/dev/null 2>&1; then
			echo "[INFO] $name already running (PID: $existing_pid)"
			echo "[INFO] Log file: $log_file"
			return 0
		fi

		echo "[WARN] Removing stale PID file: $pid_file"
		rm -f "$pid_file"
	fi

	echo "[STEP] Starting $name in background"
	nohup "$@" >"$log_file" 2>&1 &
	local pid=$!
	echo "$pid" > "$pid_file"

	echo "[INFO] $name started (PID: $pid)"
	echo "[INFO] Log file: $log_file"
}

run_network_init() {
	ensure_script_exists "$NETWORK_SCRIPT"

	echo "[STEP] Running network init script"
	if [[ "$HARDWARE_RUN_WITH_SUDO" == "1" ]]; then
		sudo bash "$NETWORK_SCRIPT"
	else
		bash "$NETWORK_SCRIPT"
	fi
}

run_hardware_stack() {
	ensure_script_exists "$IR_SCRIPT"
	ensure_script_exists "$CAM_SCRIPT"
	ensure_script_exists "$DETECT_SCRIPT"

	run_network_init

	if [[ "$HARDWARE_RUN_WITH_SUDO" == "1" ]]; then
		start_managed_process "hardware-ir" sudo python3 "$IR_SCRIPT"
		start_managed_process "hardware-cam" sudo python3 "$CAM_SCRIPT"
	else
		start_managed_process "hardware-ir" python3 "$IR_SCRIPT"
		start_managed_process "hardware-cam" python3 "$CAM_SCRIPT"
	fi

	local detect_python
	detect_python="$(resolve_detect_python)"
	start_managed_process "hardware-detect" "$detect_python" "$DETECT_SCRIPT"
}

run_backend() {
	ensure_script_exists "$BACKEND_SCRIPT"
	echo "[STEP] Running backend deploy (mode: $MODE)"
	(
		cd "$BACKEND_DIR"
		bash "$BACKEND_SCRIPT" "$MODE"
	)
}

run_frontend() {
	ensure_script_exists "$FRONTEND_SCRIPT"
	echo "[STEP] Running frontend deploy"
	(
		cd "$FRONTEND_DIR"
		bash "$FRONTEND_SCRIPT"
	)
}

install_startup() {
	ensure_script_exists "$STARTUP_SCRIPT"
	echo "[STEP] Installing startup systemd services"
	bash "$STARTUP_SCRIPT"
}

case "$TARGET" in
	all)
		run_hardware_stack
		run_backend
		run_frontend
		;;
	hardware)
		run_hardware_stack
		;;
	backend)
		run_backend
		;;
	frontend)
		run_frontend
		;;
	install-startup)
		install_startup
		;;
	-h|--help|help)
		usage
		exit 0
		;;
	*)
		echo "[ERROR] Unknown target: $TARGET"
		usage
		exit 1
		;;
esac

echo "[SUCCESS] Master deploy complete (target=$TARGET, mode=$MODE)"
