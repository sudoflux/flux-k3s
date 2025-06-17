#!/bin/bash
# K3s HA Cluster Rebuild Script
# June 16, 2025

set -euo pipefail

# Configuration
MASTER1_IP="192.168.10.30"
MASTER2_IP="192.168.10.21"
MASTER3_IP="192.168.10.23"
K3S_VERSION="v1.32.5+k3s1"

echo "=== K3s HA Cluster Installation Script ==="
echo "This will create a 3-node HA control plane cluster"
echo "Nodes: $MASTER1_IP, $MASTER2_IP, $MASTER3_IP"
echo ""

# Step 1: Install first master
echo "=== Step 1: Installing K3s on first master ($MASTER1_IP) ==="
echo "Run this on k3s-master1:"
echo ""
cat << 'EOF'
curl -sfL https://get.k3s.io | sh -s - server \
  --cluster-init \
  --disable traefik \
  --disable servicelb \
  --flannel-backend=none \
  --disable-network-policy \
  --node-name k3s-master1 \
  --tls-san 192.168.10.30 \
  --tls-san 192.168.10.21 \
  --tls-san 192.168.10.23
EOF

echo ""
echo "After installation, get the token:"
echo "sudo cat /var/lib/rancher/k3s/server/node-token"
echo ""

# Step 2: Join additional masters
echo "=== Step 2: Join k3s1 as control plane ==="
echo "Run this on k3s1 (192.168.10.21):"
echo ""
cat << 'EOF'
curl -sfL https://get.k3s.io | sh -s - server \
  --server https://192.168.10.30:6443 \
  --token <NODE_TOKEN> \
  --disable traefik \
  --disable servicelb \
  --flannel-backend=none \
  --disable-network-policy \
  --node-name k3s1 \
  --tls-san 192.168.10.30 \
  --tls-san 192.168.10.21 \
  --tls-san 192.168.10.23
EOF

echo ""
echo "=== Step 3: Join k3s2 as control plane ==="
echo "Run this on k3s2 (192.168.10.23):"
echo ""
cat << 'EOF'
curl -sfL https://get.k3s.io | sh -s - server \
  --server https://192.168.10.30:6443 \
  --token <NODE_TOKEN> \
  --disable traefik \
  --disable servicelb \
  --flannel-backend=none \
  --disable-network-policy \
  --node-name k3s2 \
  --tls-san 192.168.10.30 \
  --tls-san 192.168.10.21 \
  --tls-san 192.168.10.23
EOF

echo ""
echo "=== Step 4: Configure kubectl ==="
echo "Run this on your workstation:"
echo ""
echo "mkdir -p ~/.kube"
echo "scp k3s-master1:/etc/rancher/k3s/k3s.yaml ~/.kube/config"
echo "sed -i 's/127.0.0.1/192.168.10.30/g' ~/.kube/config"
echo ""

echo "=== Step 5: Deploy Cilium CNI ==="
echo "After all nodes are joined, deploy Cilium from your workstation"
echo ""
echo "See deploy-cilium.sh for the next steps"