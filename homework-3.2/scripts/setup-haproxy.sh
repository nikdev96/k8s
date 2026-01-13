#!/bin/bash
set -e

echo "=== Installing and configuring HAProxy ==="

# Get master node IPs from arguments
MASTER1_IP=$1
MASTER2_IP=$2
MASTER3_IP=$3

if [ -z "$MASTER1_IP" ] || [ -z "$MASTER2_IP" ] || [ -z "$MASTER3_IP" ]; then
  echo "Usage: $0 <MASTER1_IP> <MASTER2_IP> <MASTER3_IP>"
  exit 1
fi

# Install HAProxy
sudo apt-get update
sudo apt-get install -y haproxy

# Configure HAProxy
cat <<EOF | sudo tee /etc/haproxy/haproxy.cfg
global
    log /dev/log local0
    log /dev/log local1 notice
    daemon

defaults
    log global
    mode tcp
    option tcplog
    option dontlognull
    timeout connect 5000
    timeout client  50000
    timeout server  50000

frontend kubernetes-apiserver
    bind *:8443
    mode tcp
    option tcplog
    default_backend kubernetes-master

backend kubernetes-master
    mode tcp
    option tcp-check
    balance roundrobin
    server master1 ${MASTER1_IP}:6443 check fall 3 rise 2
    server master2 ${MASTER2_IP}:6443 check fall 3 rise 2
    server master3 ${MASTER3_IP}:6443 check fall 3 rise 2
EOF

# Enable and start HAProxy
sudo systemctl enable haproxy
sudo systemctl restart haproxy

echo "=== HAProxy configured successfully ==="
sudo systemctl status haproxy --no-pager
