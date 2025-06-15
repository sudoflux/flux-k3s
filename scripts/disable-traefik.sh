#!/bin/bash
# Script to disable Traefik in K3s cluster

set -euo pipefail

echo "=== K3s Traefik Disable Script ==="
echo

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Master node IP
MASTER_NODE="192.168.10.30"

echo -e "${YELLOW}Step 1: Checking current Traefik status...${NC}"
echo "Checking for Traefik resources in the cluster..."

# Check for Traefik HelmCharts
if kubectl get helmchart -n kube-system traefik &>/dev/null; then
    echo -e "${RED}Found Traefik HelmChart resources${NC}"
else
    echo -e "${GREEN}No Traefik HelmChart found${NC}"
fi

# Check for Traefik pods
TRAEFIK_PODS=$(kubectl get pods -n kube-system -o name | grep traefik || true)
if [ -n "$TRAEFIK_PODS" ]; then
    echo -e "${RED}Found Traefik pods:${NC}"
    kubectl get pods -n kube-system | grep traefik || true
else
    echo -e "${GREEN}No Traefik pods running${NC}"
fi

echo
echo -e "${YELLOW}Step 2: Updating K3s configuration on master node...${NC}"

# Create the new config.yaml content
cat > /tmp/k3s-config.yaml << 'EOF'
# K3s configuration
# Disable Traefik ingress controller
disable:
  - traefik

# Keep existing configuration
kube-apiserver-arg:
  - "feature-gates=AuthorizeNodeWithSelectors=false"
EOF

echo "New configuration prepared:"
cat /tmp/k3s-config.yaml

echo
read -p "Do you want to proceed with updating K3s configuration? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted by user"
    exit 1
fi

echo -e "${YELLOW}Step 3: Applying configuration to master node...${NC}"

# Apply configuration via SSH
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null josh@${MASTER_NODE} << 'ENDSSH'
# Backup current config
sudo cp /etc/rancher/k3s/config.yaml /etc/rancher/k3s/config.yaml.backup-$(date +%Y%m%d-%H%M%S) 2>/dev/null || true

# Create new config
sudo tee /etc/rancher/k3s/config.yaml > /dev/null << 'EOF'
# K3s configuration
# Disable Traefik ingress controller
disable:
  - traefik

# Keep existing configuration
kube-apiserver-arg:
  - "feature-gates=AuthorizeNodeWithSelectors=false"
EOF

echo "Configuration updated. Restarting K3s..."
sudo systemctl restart k3s

# Wait for K3s to be ready
sleep 10

# Check status
sudo systemctl status k3s --no-pager | head -10
ENDSSH

echo
echo -e "${YELLOW}Step 4: Cleaning up Traefik resources...${NC}"

# Delete HelmChart resources
echo "Deleting Traefik HelmChart resources..."
kubectl delete helmchart traefik -n kube-system --ignore-not-found=true
kubectl delete helmchart traefik-crd -n kube-system --ignore-not-found=true

# Delete any Traefik pods
echo "Deleting Traefik pods..."
kubectl delete pod -n kube-system -l name=helm-install-traefik --ignore-not-found=true
kubectl delete pod -n kube-system -l app.kubernetes.io/name=traefik --ignore-not-found=true

echo
echo -e "${YELLOW}Step 5: Verifying Cilium Gateway API...${NC}"

# Check Gateway resources
echo "Checking Gateway resources:"
kubectl get gateway -A

echo
echo "Checking for any remaining Traefik resources:"
kubectl get all -A | grep traefik || echo -e "${GREEN}No Traefik resources found${NC}"

echo
echo -e "${GREEN}=== Traefik disable process complete ===${NC}"
echo
echo "Summary:"
echo "- K3s configuration updated to disable Traefik"
echo "- Traefik HelmChart resources deleted"
echo "- Traefik pods cleaned up"
echo "- Cilium Gateway API verified"
echo
echo -e "${YELLOW}Note:${NC} Monitor the cluster for a few minutes to ensure everything is working correctly."