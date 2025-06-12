#!/bin/bash
# Bootstrap script for new k3s3 node (Dell R630)
# Run this on the new k3s3 node after OS installation

set -e

echo "=== K3s Node Bootstrap Script for k3s3 ==="
echo "This script will install K3s and join the node to the cluster"
echo ""

# Check if running as root or with sudo
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root or with sudo"
    exit 1
fi

# Verify hostname
CURRENT_HOSTNAME=$(hostname)
if [ "$CURRENT_HOSTNAME" != "k3s3" ]; then
    echo "ERROR: Hostname is '$CURRENT_HOSTNAME', expected 'k3s3'"
    echo "Please set hostname to 'k3s3' first:"
    echo "  hostnamectl set-hostname k3s3"
    exit 1
fi

# Verify IP address
CURRENT_IP=$(ip -4 addr show | grep -oP '192\.168\.10\.31(?=/)')
if [ -z "$CURRENT_IP" ]; then
    echo "ERROR: IP address 192.168.10.31 not found"
    echo "Please configure the network with IP 192.168.10.31 first"
    exit 1
fi

echo "✓ Hostname: $CURRENT_HOSTNAME"
echo "✓ IP Address: 192.168.10.31"
echo ""

# You'll need to get these values from k3s-master1
echo "Please provide the following information from k3s-master1:"
echo "(Run on k3s-master1: sudo cat /var/lib/rancher/k3s/server/node-token)"
echo ""
read -p "Enter K3S_TOKEN: " K3S_TOKEN

if [ -z "$K3S_TOKEN" ]; then
    echo "ERROR: K3S_TOKEN cannot be empty"
    exit 1
fi

# K3s server URL
K3S_URL="https://192.168.10.30:6443"

echo ""
echo "Installing K3s agent..."

# Install K3s agent
curl -sfL https://get.k3s.io | K3S_URL=$K3S_URL K3S_TOKEN=$K3S_TOKEN sh -

echo ""
echo "Waiting for K3s to start..."
sleep 10

# Check service status
systemctl status k3s-agent --no-pager

echo ""
echo "=== Bootstrap Complete ==="
echo "The node should now be joining the cluster."
echo "Verify on k3s-master1 with: kubectl get nodes"