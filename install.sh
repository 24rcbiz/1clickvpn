#!/bin/bash

echo -e "\033[1;36m[*]\033[0m 24rc.biz :: Установка WireGuard"

if [[ "$EUID" -ne 0 ]]; then
  echo -e "\033[1;31m[!]\033[0m Запусти от root."
  exit 1
fi

ping -c 1 1.1.1.1 >/dev/null 2>&1 || { echo -e "\033[1;31m[!]\033[0m Нет интернета."; exit 1; }

apt update -y
apt install -y wireguard iptables resolvconf qrencode

DEFAULT_INTERFACE=$(ip route get 1.1.1.1 | awk '{print $5; exit}')
PUBLIC_IP=$(curl -s ifconfig.me)
WG_PORT=$((RANDOM % 16383 + 49152))

SERVER_PRIV_KEY=$(wg genkey)
SERVER_PUB_KEY=$(echo "$SERVER_PRIV_KEY" | wg pubkey)

SERVER_IP="10.66.66.1/24"
CLIENT_IP="10.66.66.2/32"
DNS1="1.1.1.1"
DNS2="1.0.0.1"
WG_INTERFACE="wg0"

mkdir -p /etc/wireguard

cat > /etc/wireguard/$WG_INTERFACE.conf <<EOF
[Interface]
Address = $SERVER_IP
ListenPort = $WG_PORT
PrivateKey = $SERVER_PRIV_KEY
PostUp = iptables -A FORWARD -i $WG_INTERFACE -j ACCEPT; iptables -A FORWARD -o $WG_INTERFACE -j ACCEPT; iptables -t nat -A POSTROUTING -o $DEFAULT_INTERFACE -j MASQUERADE
PostDown = iptables -D FORWARD -i $WG_INTERFACE -j ACCEPT; iptables -D FORWARD -o $WG_INTERFACE -j ACCEPT; iptables -t nat -D POSTROUTING -o $DEFAULT_INTERFACE -j MASQUERADE
EOF

sysctl -w net.ipv4.ip_forward=1 >/dev/null
echo "net.ipv4.ip_forward=1" > /etc/sysctl.d/99-sysctl.conf

systemctl enable wg-quick@$WG_INTERFACE
systemctl restart wg-quick@$WG_INTERFACE

CLIENT_PRIV_KEY=$(wg genkey)
CLIENT_PUB_KEY=$(echo "$CLIENT_PRIV_KEY" | wg pubkey)

wg set $WG_INTERFACE peer $CLIENT_PUB_KEY allowed-ips $CLIENT_IP

CLIENT_CONF="[Interface]
PrivateKey = $CLIENT_PRIV_KEY
Address = $CLIENT_IP
DNS = $DNS1,$DNS2

[Peer]
PublicKey = $SERVER_PUB_KEY
Endpoint = $PUBLIC_IP:$WG_PORT
AllowedIPs = 0.0.0.0/0,::/0
PersistentKeepalive = 25
"

echo
echo "$CLIENT_CONF"
echo
echo "$CLIENT_CONF" | qrencode -t ansiutf8
echo
echo "Готово. Используй конфиг или QR-код для подключения. Ваш 24rc.biz - заходи"
