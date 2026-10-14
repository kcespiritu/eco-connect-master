# EcoConnect

A reverse-vending kiosk that runs its own Wi-Fi network. A user joins the kiosk's hotspot, lands on a
captive portal, deposits a bottle, and is rewarded for it.

Built as paid technical support for a university thesis team.

## How it works

**1. The kiosk is its own network.** A Raspberry Pi runs an access point (`hostapd`, SSID `EcoConnect`)
with its own DHCP server and a captive-portal redirect: port 80 traffic from the Wi-Fi is DNAT'd to the
Pi, so whatever a phone tries to load lands on the portal. Clients get outbound internet only once they
are added to the `allowed_clients` ipset — the portal gates access rather than just displaying a page.

**2. A bottle is verified, not merely detected.** A headless YOLOv8n detector (`hardware/detect.py`) reads
shared camera frames, looks for the `bottle` class, and posts a decision to the backend. A two-second
cooldown stops a single bottle being counted twice. An IR sensor on GPIO17 (`hardware/ir.py`) provides a
simpler second trigger path.

**3. The backend owns the state.** An Express service tracks sessions, applies the reward rule, and
persists to SQLite. It also drives the gate and controls the hotspot.

**4. The gate is a servo on an Arduino.** The backend sends single-character commands over serial — `o`
open, `c` close, `+` / `-` nudge, `s` status. The firmware carries a keep-alive pulse every few seconds
so the servo keeps drawing current and a USB power bank does not sleep mid-event. It skips that pulse
while the gate is open, so it cannot interfere with a drop in progress.

**5. The kiosk display is React.** Captive portal, kiosk display and an admin test page, with hooks for
detection, session countdown and sound.

## Layers

| Path | Contents |
| --- | --- |
| `hardware/` | Arduino firmware (servo gate), YOLO bottle detection, IR trigger, hotspot and captive-portal network setup |
| `apps/backend/` | Express API — sessions, rewards, gate control, hotspot control, SQLite |
| `apps/frontend/` | React kiosk UI — captive portal, display, admin test page |
| `apps/backend/deploy/systemd/` | Boot-persistent units for the backend and detector |

## Running it

### deploy-master.sh quick guide

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

### Running it without the physical rig

`SERVO_MOCK=1` stubs the servo, and `HOTSPOT_STRICT=0` lets the network layer come up on a machine that
is not the kiosk. The full stack can therefore be exercised before any hardware is wired.

## Configuration

Backend settings live in `apps/backend/.env` — see `apps/backend/.env.example` for the full surface:
reward per bottle, detection confidence threshold, servo serial port and command characters, log level,
and hotspot behaviour.

## Stack

Raspberry Pi · Arduino · Python (Ultralytics YOLOv8, OpenCV, gpiozero) · Node.js and Express · SQLite ·
React with Vite and Tailwind · hostapd, dnsmasq, iptables · systemd
