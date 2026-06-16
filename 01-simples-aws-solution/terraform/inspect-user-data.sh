#!/bin/bash
set -ex
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
# =============================================
# GWLB Tunnel Create Script - Simple Passthrough
# =============================================

echo "==> GWLB Passthrough Setup | Mode=$1 | In=$2 | Out=$3 | ENI=$4"

# Clean old tc rules
tc qdisc del dev "$2" ingress 2>/dev/null || true

# tc Mirroring (critical for GWLB passthrough)
tc qdisc add dev "$2" ingress 2>/dev/null || true
tc filter add dev "$2" parent ffff: protocol all prio 2 u32 match u32 0 0 flowid 1:1 action mirred egress mirror dev "$3"

# Networking settings
echo 0 > /proc/sys/net/ipv4/conf/"$2"/rp_filter
echo 0 > /proc/sys/net/ipv4/conf/"$3"/rp_filter
echo 0 > /proc/sys/net/ipv4/conf/all/rp_filter
echo 1 > /proc/sys/net/ipv4/ip_forward
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
