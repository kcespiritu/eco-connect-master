#!/bin/bash
set -euo pipefail

echo "=== EcoConnect Captive Portal START ==="

DEFAULT_LAN_IF="wlan0"
DEFAULT_WAN_IF="eth0"
DEFAULT_AP_IP="10.42.0.1/24"
NETWORK_TMP_DIR="${NETWORK_TMP_DIR:-/var/lib/ecoconnect/runtime}"
HOSTAPD_CONFIG=""
DNSMASQ_CONFIG=""

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "[ERROR] Required command not found: $1"
    exit 1
  fi
}

iface_exists() {
  local iface="$1"
  [[ -n "$iface" && -d "/sys/class/net/$iface" ]]
}

detect_wan_if() {
  ip route show default 2>/dev/null | awk '/default/ {print $5; exit}'
}

detect_lan_if() {
  local wan_if="$1"
  local wifi_if

  for wifi_if in /sys/class/net/wl*; do
    [[ -e "$wifi_if" ]] || continue
    wifi_if="$(basename "$wifi_if")"
    if [[ "$wifi_if" != "$wan_if" ]]; then
      echo "$wifi_if"
      return 0
    fi
  done

  return 1
}

derive_gateway_from_cidr() {
  local cidr="$1"
  echo "$cidr" | awk -F/ '{print $1}'
}

derive_dhcp_range() {
  local cidr="$1"
  local ip mask base

  ip="$(echo "$cidr" | awk -F/ '{print $1}')"
  mask="$(echo "$cidr" | awk -F/ '{print $2}')"

  if [[ "$mask" != "24" ]]; then
    echo ""
    return 0
  fi

  base="$(echo "$ip" | awk -F. '{print $1"."$2"."$3}')"
  echo "${base}.10,${base}.200,12h"
}

require_cmd ip
require_cmd iptables
require_cmd ipset
require_cmd hostapd
require_cmd dnsmasq
require_cmd sysctl
require_cmd mktemp

mkdir -p "$NETWORK_TMP_DIR" >/dev/null 2>&1 || true

if [[ ! -d "$NETWORK_TMP_DIR" ]] || [[ ! -w "$NETWORK_TMP_DIR" ]]; then
  NETWORK_TMP_DIR="${XDG_RUNTIME_DIR:-/tmp}"
fi

if [[ ! -d "$NETWORK_TMP_DIR" ]] || [[ ! -w "$NETWORK_TMP_DIR" ]]; then
  NETWORK_TMP_DIR="/tmp"
fi

HOSTAPD_CONFIG="$(mktemp "$NETWORK_TMP_DIR/ecoconnect-hostapd.XXXXXX.conf")"
DNSMASQ_CONFIG="$(mktemp "$NETWORK_TMP_DIR/ecoconnect-dnsmasq.XXXXXX.conf")"

cleanup_tmp_files() {
  rm -f "$HOSTAPD_CONFIG" "$DNSMASQ_CONFIG" >/dev/null 2>&1 || true
}

trap cleanup_tmp_files EXIT

WAN_IF="${WAN_IF:-$DEFAULT_WAN_IF}"
if [[ -z "$WAN_IF" ]] || ! iface_exists "$WAN_IF"; then
  detected_wan="$(detect_wan_if || true)"
  if iface_exists "$detected_wan"; then
    WAN_IF="$detected_wan"
  fi
fi

LAN_IF="${LAN_IF:-$DEFAULT_LAN_IF}"
if [[ -z "$LAN_IF" ]] || ! iface_exists "$LAN_IF"; then
  detected_lan="$(detect_lan_if "$WAN_IF" || true)"
  if iface_exists "$detected_lan"; then
    LAN_IF="$detected_lan"
  fi
fi

AP_IP="${AP_IP:-$DEFAULT_AP_IP}"
GATEWAY="${GATEWAY:-$(derive_gateway_from_cidr "$AP_IP")}"
DHCP_RANGE="${DHCP_RANGE:-$(derive_dhcp_range "$AP_IP")}"

if ! iface_exists "$LAN_IF"; then
  echo "[ERROR] LAN interface not found: $LAN_IF"
  echo "[HINT] Set LAN_IF explicitly, for example: LAN_IF=wlan0"
  exit 1
fi

if ! iface_exists "$WAN_IF"; then
  echo "[ERROR] WAN interface not found: $WAN_IF"
  echo "[HINT] Set WAN_IF explicitly, for example: WAN_IF=eth0"
  exit 1
fi

if [[ "$LAN_IF" == "$WAN_IF" ]]; then
  echo "[ERROR] LAN_IF and WAN_IF must be different (both were '$LAN_IF')."
  exit 1
fi

if [[ -z "$DHCP_RANGE" ]]; then
  echo "[ERROR] Could not derive DHCP range from AP_IP=$AP_IP"
  echo "[HINT] Set DHCP_RANGE explicitly, for example: DHCP_RANGE=192.168.77.10,192.168.77.200,12h"
  exit 1
fi

echo "[INFO] LAN_IF=$LAN_IF WAN_IF=$WAN_IF AP_IP=$AP_IP GATEWAY=$GATEWAY"

# -----------------------------
# STOP SERVICES
# -----------------------------
systemctl stop hostapd 2>/dev/null || true
systemctl stop dnsmasq 2>/dev/null || true

pkill hostapd 2>/dev/null || true
pkill dnsmasq 2>/dev/null || true

# -----------------------------
# RESET NETWORK INTERFACE
# -----------------------------
nmcli dev set "$LAN_IF" managed no 2>/dev/null || true
nmcli dev disconnect "$LAN_IF" 2>/dev/null || true

ip link set "$LAN_IF" down
ip addr flush dev "$LAN_IF"
ip link set "$LAN_IF" up

# -----------------------------
# SET AP IP
# -----------------------------
ip addr replace "$AP_IP" dev "$LAN_IF"

# -----------------------------
# HOSTAPD CONFIG (AUTO)
# -----------------------------
cat > "$HOSTAPD_CONFIG" <<EOF
interface=$LAN_IF
driver=nl80211
ssid=EcoConnect
hw_mode=g
channel=6
auth_algs=1
wmm_enabled=1
EOF

# START HOSTAPD (NON-BLOCKING)
hostapd -B "$HOSTAPD_CONFIG"

# -----------------------------
# DNSMASQ CONFIG (AUTO)
# -----------------------------
cat > "$DNSMASQ_CONFIG" <<EOF
interface=$LAN_IF
bind-interfaces
dhcp-authoritative

dhcp-range=$DHCP_RANGE
dhcp-option=3,$GATEWAY
dhcp-option=6,$GATEWAY

log-dhcp
EOF

# START DNSMASQ (FIXED LIFECYCLE)
pkill dnsmasq 2>/dev/null || true
sleep 5

dnsmasq -C "$DNSMASQ_CONFIG" \
  --bind-interfaces \
  --log-dhcp \
  --rebind-localhost-ok \
  --no-daemon &

# -----------------------------
# ROUTING
# -----------------------------
sysctl -w net.ipv4.ip_forward=1

# -----------------------------
# IPSET (MUST EXIST BEFORE RULES)
# -----------------------------
ipset create allowed_clients hash:ip -exist

# -----------------------------
# FIREWALL RESET
# -----------------------------
iptables -F
iptables -t nat -F
iptables -P FORWARD DROP

# allow established
iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

# allow authorized clients
iptables -A FORWARD -m set --match-set allowed_clients src -j ACCEPT

# block all other LAN → WAN
iptables -A FORWARD -i "$LAN_IF" -o "$WAN_IF" -j DROP

# -----------------------------
# NAT INTERNET SHARING
# -----------------------------
iptables -t nat -A POSTROUTING -o "$WAN_IF" -j MASQUERADE

# -----------------------------
# CAPTIVE PORTAL REDIRECT (HTTP ONLY)
# -----------------------------
iptables -t nat -A PREROUTING -i "$LAN_IF" -p tcp --dport 80 -j DNAT --to "$GATEWAY:80"

echo "=== EcoConnect READY ==="