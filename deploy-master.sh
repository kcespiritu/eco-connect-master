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
HARDWARE_SOFT_FAIL_OPTIONAL="${HARDWARE_SOFT_FAIL_OPTIONAL:-1}"
MASTER_RUNTIME_DIR="${MASTER_RUNTIME_DIR:-$ROOT_DIR/.runtime}"
MASTER_LOG_DIR="${MASTER_LOG_DIR:-$ROOT_DIR/logs}"
STARTUP_SCRIPT="$ROOT_DIR/configure-startup.sh"
PROCESS_STARTUP_CHECK_SECONDS="${PROCESS_STARTUP_CHECK_SECONDS:-2}"

SUDO_VALIDATED=0

usage() {
	cat <<'EOF'
Usage:
	./deploy-master.sh [target] [mode]

Targets:
	all        Run hardware stack, then backend and frontend (default)
	hardware   Run hardware stack only
	backend    Deploy backend only
	frontend   Deploy frontend only
	status     Show runtime status for hardware/background and systemd services
	stop       Stop hardware/background and ecoconnect systemd services
	install-startup  Install and enable systemd services for reboot persistence

Modes:
	prod       Backend: systemd deploy, Frontend: build + nginx deploy (default)
	dev        Backend: start dev server in background, Frontend: still does build + nginx deploy

Examples:
	./deploy-master.sh
	./deploy-master.sh all prod
	./deploy-master.sh backend dev
	./deploy-master.sh frontend prod
	./deploy-master.sh status
	./deploy-master.sh stop

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
	- Optional hardware soft-fail behavior (default enabled):
		HARDWARE_SOFT_FAIL_OPTIONAL=1  # cam.py and detect.py failures won't stop deploy
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

ensure_sudo_access() {
	if [[ "$SUDO_VALIDATED" == "1" ]]; then
		return 0
	fi

	if ! command -v sudo >/dev/null 2>&1; then
		echo "[ERROR] sudo is required for this operation."
		exit 1
	fi

	echo "[STEP] Validating sudo access"
	if ! sudo -v; then
		echo "[ERROR] Unable to validate sudo access."
		exit 1
	fi

	SUDO_VALIDATED=1
}

is_pid_running() {
	local pid="$1"
	[[ -n "$pid" ]] && kill -0 "$pid" >/dev/null 2>&1
}

resolve_detect_python() {
	if [[ -n "$DETECT_PYTHON" ]]; then
		echo "$DETECT_PYTHON"
		return 0
	fi

	if [[ -n "$DETECT_VENV_PATH" ]]; then
		if [[ -x "$DETECT_VENV_PATH/bin/python3" ]]; then
			echo "$DETECT_VENV_PATH/bin/python3"
			return 0
		fi

		if [[ -x "$DETECT_VENV_PATH/bin/python" ]]; then
			echo "$DETECT_VENV_PATH/bin/python"
			return 0
		fi

		echo "[ERROR] DETECT_VENV_PATH is set but python not found: $DETECT_VENV_PATH/bin/python3 or $DETECT_VENV_PATH/bin/python"
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

	sleep "$PROCESS_STARTUP_CHECK_SECONDS"
	if ! kill -0 "$pid" >/dev/null 2>&1; then
		echo "[ERROR] $name failed to stay running after startup check."
		echo "[ERROR] Check logs: $log_file"
		rm -f "$pid_file"
		exit 1
	fi

	echo "[INFO] $name started (PID: $pid)"
	echo "[INFO] Log file: $log_file"
}

start_managed_process_optional() {
	local name="$1"
	shift

	if [[ "$HARDWARE_SOFT_FAIL_OPTIONAL" != "1" ]]; then
		start_managed_process "$name" "$@"
		return 0
	fi

	if ! start_managed_process "$name" "$@"; then
		echo "[WARN] Optional process '$name' failed to start; continuing deploy"
		return 1
	fi

	return 0
}

stop_managed_process() {
	local name="$1"
	local pid_file="$MASTER_RUNTIME_DIR/${name}.pid"

	if [[ ! -f "$pid_file" ]]; then
		echo "[INFO] $name not running (no PID file)"
		return 0
	fi

	local pid
	pid="$(cat "$pid_file")"

	if ! is_pid_running "$pid"; then
		echo "[INFO] $name already stopped (stale PID: $pid)"
		rm -f "$pid_file"
		return 0
	fi

	echo "[STEP] Stopping $name (PID: $pid)"
	kill -- "-$pid" >/dev/null 2>&1 || kill "$pid" >/dev/null 2>&1 || true
	sleep 1

	if is_pid_running "$pid"; then
		echo "[WARN] $name did not stop after SIGTERM; sending SIGKILL"
		kill -9 -- "-$pid" >/dev/null 2>&1 || kill -9 "$pid" >/dev/null 2>&1 || true
	fi

	rm -f "$pid_file"
	echo "[INFO] $name stopped"
}

status_managed_process() {
	local name="$1"
	local pid_file="$MASTER_RUNTIME_DIR/${name}.pid"

	if [[ ! -f "$pid_file" ]]; then
		echo "[STATUS] $name: not running (no PID file)"
		return 0
	fi

	local pid
	pid="$(cat "$pid_file")"
	if is_pid_running "$pid"; then
		echo "[STATUS] $name: running (PID: $pid)"
	else
		echo "[STATUS] $name: not running (stale PID: $pid)"
	fi
}

status_systemd_service() {
	local service_name="$1"

	if ! command -v systemctl >/dev/null 2>&1; then
		echo "[STATUS] $service_name: systemctl unavailable"
		return 0
	fi

	if ! systemctl list-unit-files | grep -q "^${service_name}\.service"; then
		echo "[STATUS] $service_name: not installed"
		return 0
	fi

	local state
	state="$(systemctl is-active "${service_name}.service" 2>/dev/null || true)"
	local enabled
	enabled="$(systemctl is-enabled "${service_name}.service" 2>/dev/null || true)"
	echo "[STATUS] $service_name: active=$state enabled=$enabled"
}

run_network_init() {
	ensure_script_exists "$NETWORK_SCRIPT"

	echo "[STEP] Running network init script"
	if [[ "$HARDWARE_RUN_WITH_SUDO" == "1" ]]; then
		ensure_sudo_access
		sudo bash "$NETWORK_SCRIPT"
	else
		bash "$NETWORK_SCRIPT"
	fi
}

run_hardware_stack() {
	ensure_script_exists "$IR_SCRIPT"

	if [[ ! -f "$CAM_SCRIPT" ]]; then
		echo "[WARN] Optional script missing: $CAM_SCRIPT"
	fi

	if [[ ! -f "$DETECT_SCRIPT" ]]; then
		echo "[WARN] Optional script missing: $DETECT_SCRIPT"
	fi

	run_network_init

	if [[ "$HARDWARE_RUN_WITH_SUDO" == "1" ]]; then
		ensure_sudo_access
		start_managed_process "hardware-ir" sudo -n python3 "$IR_SCRIPT"
		if [[ -f "$CAM_SCRIPT" ]]; then
			start_managed_process_optional "hardware-cam" sudo -n python3 "$CAM_SCRIPT"
		fi
	else
		start_managed_process "hardware-ir" python3 "$IR_SCRIPT"
		if [[ -f "$CAM_SCRIPT" ]]; then
			start_managed_process_optional "hardware-cam" python3 "$CAM_SCRIPT"
		fi
	fi

	if [[ -f "$DETECT_SCRIPT" ]]; then
		local detect_python
		detect_python="$(resolve_detect_python)"
		start_managed_process_optional "hardware-detect" "$detect_python" "$DETECT_SCRIPT"
	fi
}

run_backend() {
	ensure_script_exists "$BACKEND_SCRIPT"
	if [[ "$MODE" == "prod" ]]; then
		ensure_sudo_access
	fi
	echo "[STEP] Running backend deploy (mode: $MODE)"
	(
		cd "$BACKEND_DIR"
		bash "$BACKEND_SCRIPT" "$MODE"
	)
}

run_frontend() {
	ensure_script_exists "$FRONTEND_SCRIPT"
	ensure_sudo_access
	echo "[STEP] Running frontend deploy"
	(
		cd "$FRONTEND_DIR"
		bash "$FRONTEND_SCRIPT"
	)
}

show_status() {
	echo "[STEP] Checking managed hardware process status"
	status_managed_process "hardware-ir"
	status_managed_process "hardware-cam"
	status_managed_process "hardware-detect"

	echo "[STEP] Checking ecoconnect systemd service status"
	status_systemd_service "ecoconnect-network"
	status_systemd_service "ecoconnect-ir"
	status_systemd_service "ecoconnect-cam"
	status_systemd_service "ecoconnect-detect"
	status_systemd_service "ecoconnect-backend"
	status_systemd_service "ecoconnect-frontend"

	# Legacy service is shown for troubleshooting migration conflicts.
	status_systemd_service "ecoconnect-detector"
}

stop_all() {
	echo "[STEP] Stopping managed hardware background processes"
	stop_managed_process "hardware-ir"
	stop_managed_process "hardware-cam"
	stop_managed_process "hardware-detect"

	if [[ -f "$BACKEND_SCRIPT" ]]; then
		echo "[STEP] Stopping backend dev server"
		(
			cd "$BACKEND_DIR"
			bash "$BACKEND_SCRIPT" stop
		)
	fi

	if command -v systemctl >/dev/null 2>&1; then
		ensure_sudo_access
		echo "[STEP] Stopping ecoconnect systemd services (if installed)"
		sudo systemctl stop ecoconnect-frontend.service 2>/dev/null || true
		sudo systemctl stop ecoconnect-backend.service 2>/dev/null || true
		sudo systemctl stop ecoconnect-detect.service 2>/dev/null || true
		sudo systemctl stop ecoconnect-cam.service 2>/dev/null || true
		sudo systemctl stop ecoconnect-ir.service 2>/dev/null || true
		sudo systemctl stop ecoconnect-network.service 2>/dev/null || true
		sudo systemctl stop ecoconnect-detector.service 2>/dev/null || true
	fi

	echo "[SUCCESS] Stop sequence complete"
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
	status)
		show_status
		;;
	stop)
		stop_all
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
