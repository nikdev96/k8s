#!/bin/bash
set -e

echo "=== Installing and configuring keepalived ==="

# Get parameters
ROLE=$1        # MASTER or BACKUP
PRIORITY=$2    # 101 for master1, 100 for master2, 99 for master3
VIP=$3         # Virtual IP address
INTERFACE=$4   # Network interface (default: ens4)

if [ -z "$ROLE" ] || [ -z "$PRIORITY" ] || [ -z "$VIP" ]; then
  echo "Usage: $0 <ROLE(MASTER|BACKUP)> <PRIORITY(101|100|99)> <VIP> [INTERFACE]"
  exit 1
fi

if [ -z "$INTERFACE" ]; then
  INTERFACE="ens4"
fi

# Install keepalived
sudo apt-get update
sudo apt-get install -y keepalived

# Configure keepalived
cat <<EOF | sudo tee /etc/keepalived/keepalived.conf
vrrp_script check_haproxy {
    script "/usr/bin/killall -0 haproxy"
    interval 2
    weight 2
}

vrrp_instance VI_1 {
    state ${ROLE}
    interface ${INTERFACE}
    virtual_router_id 51
    priority ${PRIORITY}
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass 1234
    }
    virtual_ipaddress {
        ${VIP}
    }
    track_script {
        check_haproxy
    }
}
EOF

# Enable and start keepalived
sudo systemctl enable keepalived
sudo systemctl start keepalived

echo "=== keepalived configured successfully ==="
sudo systemctl status keepalived --no-pager
