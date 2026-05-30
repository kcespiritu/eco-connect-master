# eco-connect-master

## deploy-master.sh Quick Guide

Run everything from the repository root with the master script:

```bash
./deploy-master.sh all prod
```

Common commands:

```bash
./deploy-master.sh backend dev
./deploy-master.sh frontend prod
./deploy-master.sh hardware
./deploy-master.sh install-startup
./deploy-master.sh status
./deploy-master.sh stop
```

What each one does:

- `all prod` runs hardware networking, backend, and frontend startup in order.
- `backend dev` starts the backend in background dev mode.
- `frontend prod` builds and deploys the frontend.
- `hardware` runs the hotspot/network setup and hardware processes only.
- `install-startup` installs the systemd services so they start on boot.
- `status` shows what is currently running.
- `stop` stops the managed services and background processes.

Useful overrides:

```bash
LAN_IF=wlan0 WAN_IF=eth0 AP_IP=192.168.77.1/24 ./deploy-master.sh all prod
SERVO_MOCK=1 HOTSPOT_STRICT=0 ./deploy-master.sh backend dev
DETECT_PYTHON=/path/to/venv/bin/python ./deploy-master.sh install-startup
```

Sample cases:

```bash
# Full production deploy on the Pi
LAN_IF=wlan0 WAN_IF=eth0 AP_IP=10.42.0.1/24 SERVO_MOCK=0 ./deploy-master.sh all prod

# Just test backend + hotspot/network without real servo hardware
LAN_IF=wlan0 WAN_IF=eth0 AP_IP=192.168.77.1/24 SERVO_MOCK=1 HOTSPOT_STRICT=0 ./deploy-master.sh backend dev
sudo LAN_IF=wlan0 WAN_IF=eth0 AP_IP=192.168.77.1/24 bash hardware/network.sh
```