#!/bin/bash
# Script to join k3s1 and k3s2 as control plane nodes

K3S_TOKEN="K101f7d91b874527e10861f812ccde452f0f424bfbb0a6cf25cc88762952974a5ab::server:d8d54920931fa9132163f0fd6f2f779d"
K3S_URL="https://192.168.10.30:6443"

echo "Adding k3s1 (192.168.10.21) as control plane node..."
ssh k3s1 "curl -sfL https://get.k3s.io | K3S_URL='${K3S_URL}' K3S_TOKEN='${K3S_TOKEN}' sh -s - server \
  --disable traefik \
  --disable servicelb \
  --flannel-backend=none \
  --disable-network-policy \
  --node-name k3s1"

echo "Adding k3s2 (192.168.10.23) as control plane node..."
ssh k3s2 "curl -sfL https://get.k3s.io | K3S_URL='${K3S_URL}' K3S_TOKEN='${K3S_TOKEN}' sh -s - server \
  --disable traefik \
  --disable servicelb \
  --flannel-backend=none \
  --disable-network-policy \
  --node-name k3s2"

echo "Waiting for nodes to join..."
sleep 30

echo "Checking cluster status..."
kubectl get nodes -o wide