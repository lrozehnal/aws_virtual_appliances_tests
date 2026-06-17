#!/bin/bash
set -ex
BASTION_IP="${BASTION_IP}"
sudo sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf
sudo dnf groupinstall "Development Tools" -y
sudo dnf install gcc gcc-c++ cmake git wget tcpdump iptables-services iproute-tc -y

cd /home/ec2-user
wget https://archives.boost.io/release/1.83.0/source/boost_1_83_0.tar.gz
tar -xzf boost_1_83_0.tar.gz
sudo mv boost_1_83_0 boost

cd /opt
sudo git clone https://github.com/aws-samples/aws-gateway-load-balancer-tunnel-handler.git
cd /opt/aws-gateway-load-balancer-tunnel-handler
sudo cmake -DBOOST_INCLUDEDIR=/home/ec2-user/boost .
sudo make

sudo chmod +x gwlbtun
sudo setcap cap_net_admin+ep ./gwlbtun


cat << 'EOF' | sudo tee /opt/simple-passthrough-script.sh > /dev/null
#!/bin/bash
# ======================================================================================================
# GWLB Passthrough Routing + Block Port 80 inbound and forward outbound port 80 and 443 to nearby proxy
# ======================================================================================================

IN_IFACE="$2"
OUT_IFACE="$3"
BASTION_IP="${BASTION_IP}"

echo "==> GWLB Passthrough - Bastion IP = \$BASTION_IP"
echo "    Inbound=$IN_IFACE | Outbound=$OUT_IFACE"

# === Interfaces & IPs ===
ip link set dev "$IN_IFACE" up 2>/dev/null || true
ip link set dev "$OUT_IFACE" up 2>/dev/null || true

ip addr flush dev "$IN_IFACE" 2>/dev/null
ip addr flush dev "$OUT_IFACE" 2>/dev/null
ip addr add 169.254.101.2/30 dev "$IN_IFACE"
ip addr add 169.254.102.2/30 dev "$OUT_IFACE"

# Forwarding + rp_filter
echo 1 > /proc/sys/net/ipv4/ip_forward
echo 0 > /proc/sys/net/ipv4/conf/all/rp_filter
echo 0 > /proc/sys/net/ipv4/conf/"$IN_IFACE"/rp_filter
echo 0 > /proc/sys/net/ipv4/conf/"$OUT_IFACE"/rp_filter

# === Routing ===
ip route del default via 169.254.102.1 dev "$OUT_IFACE" 2>/dev/null || true
ip route add default via 169.254.102.1 dev "$OUT_IFACE"
  ip route del default  dev ens5

# === iptables - SAFE VERSION ===
echo "==> Applying safe iptables rules..."

# Flush rules
iptables -F
iptables -t nat -F
iptables -t mangle -F

# Allow SSH from anywhere first (critical!)
iptables -A INPUT -p tcp --dport 22 -j ACCEPT

# Allow established connections
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Default policies - INPUT stays ACCEPT for management
iptables -P INPUT ACCEPT
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# === BLOCK PORT 80 inbound ===
iptables -A FORWARD -i "$IN_IFACE" -p tcp -d 10.1.0.0/24 --dport 80 -j DROP

# === forward traffic via squid proxy ===

# Explicit rule for your client subnet
iptables -t nat -A PREROUTING -i "$IN_IFACE" -s 10.1.0.0/24 -p tcp --dport 80 -j DNAT --to-destination $BASTION_IP:3128
iptables -t nat -A PREROUTING -i "$IN_IFACE"  -s 10.1.0.0/24 -p tcp --dport 443 -j DNAT --to-destination $BASTION_IP:3128
iptables -t nat -A POSTROUTING -d $BASTION_IP -p tcp --dport 3128 -j MASQUERADE

# Allow other forwarded traffic
iptables -A FORWARD -i "$IN_IFACE" -j ACCEPT
iptables -A FORWARD -i "$OUT_IFACE" -j ACCEPT

echo "==> Setup complete (Safe mode)"
echo "    Port 80 blocked inbound"
echo "    SSH should remain accessible"
EOF



sudo chmod +x  /opt/simple-passthrough-script.sh



cat << 'EOF' | sudo tee /etc/systemd/system/gwlbtun.service > /dev/null
[Unit]
Description=AWS Gateway Load Balancer Tunnel Handler
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/opt/aws-gateway-load-balancer-tunnel-handler/gwlbtun -c /opt/simple-passthrough-script.sh -p 6081
WorkingDirectory=/opt/aws-gateway-load-balancer-tunnel-handler

CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_RAW CAP_SYS_ADMIN
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_RAW CAP_SYS_ADMIN

User=root
Group=root

Restart=always
RestartSec=3
StartLimitIntervalSec=0

LimitNOFILE=65535
LimitMEMLOCK=infinity

ProtectSystem=off
ProtectHome=off
PrivateTmp=no

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl restart gwlbtun
sudo systemctl enable gwlbtun
sudo systemctl status gwlbtun -n 30


sudo systemctl restart squid
sudo systemctl enable squid
sudo systemctl status squid -n 30