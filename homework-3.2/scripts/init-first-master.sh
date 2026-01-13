#!/bin/bash
set -e

echo "=== Initializing first master node ==="

# Get parameters
MASTER1_IP=$1
VIP=$2

if [ -z "$MASTER1_IP" ] || [ -z "$VIP" ]; then
  echo "Usage: $0 <MASTER1_IP> <VIP>"
  exit 1
fi

# Create kubeadm config with actual IPs
cat <<EOF > /tmp/kubeadm-config.yaml
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
kubernetesVersion: v1.28.0
controlPlaneEndpoint: "${VIP}:8443"
networking:
  podSubnet: "192.168.0.0/16"
  serviceSubnet: "10.96.0.0/12"
etcd:
  local:
    dataDir: /var/lib/etcd
apiServer:
  certSANs:
  - "${VIP}"
  - "${MASTER1_IP}"
  extraArgs:
    authorization-mode: "Node,RBAC"
  timeoutForControlPlane: 4m0s
controllerManager:
  extraArgs:
    bind-address: "0.0.0.0"
scheduler:
  extraArgs:
    bind-address: "0.0.0.0"
---
apiVersion: kubeadm.k8s.io/v1beta3
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: "${MASTER1_IP}"
  bindPort: 6443
nodeRegistration:
  criSocket: unix:///var/run/containerd/containerd.sock
  taints:
  - effect: NoSchedule
    key: node-role.kubernetes.io/control-plane
---
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
cgroupDriver: systemd
EOF

echo "=== Initializing Kubernetes cluster ==="
sudo kubeadm init --config /tmp/kubeadm-config.yaml --upload-certs

echo "=== Setting up kubectl for current user ==="
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

echo "=== First master initialized successfully ==="
echo ""
echo "Save the join commands from above!"
echo "You will need them to join other master and worker nodes."
