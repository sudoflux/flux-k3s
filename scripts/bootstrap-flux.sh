#!/bin/bash
# Bootstrap Flux GitOps
# June 16, 2025

set -euo pipefail

echo "=== Bootstrapping Flux GitOps ==="

# Check if flux CLI is installed
if ! command -v flux &> /dev/null; then
    echo "Installing Flux CLI..."
    curl -s https://fluxcd.io/install.sh | sudo bash
fi

# Create flux-system namespace
echo "Creating flux-system namespace..."
kubectl create namespace flux-system --dry-run=client -o yaml | kubectl apply -f -

# Restore SOPS age key
echo "Restoring SOPS age key..."
if [ -f /tmp/age.key ]; then
    kubectl create secret generic sops-age \
        --namespace=flux-system \
        --from-file=age.agekey=/tmp/age.key \
        --dry-run=client -o yaml | kubectl apply -f -
else
    echo "WARNING: SOPS age key not found at /tmp/age.key"
    echo "You'll need to restore it manually"
fi

# Apply Flux components
echo "Installing Flux components..."
kubectl apply -f clusters/k3s-home/flux-system/gotk-components.yaml

# Apply Flux sync configuration
echo "Configuring Flux sync..."
kubectl apply -f clusters/k3s-home/flux-system/gotk-sync.yaml

# Wait for Flux to be ready
echo "Waiting for Flux to be ready..."
kubectl wait --for=condition=ready pods -n flux-system --all --timeout=300s

# Check Flux status
echo "Checking Flux status..."
flux check

echo ""
echo "=== Flux Bootstrap Complete ==="
echo ""
echo "Flux will now start reconciling the cluster state from Git"
echo "Monitor progress with:"
echo "  watch flux get all -A"
echo ""
echo "Key applications will be deployed in this order:"
echo "1. Infrastructure (Gateway API, Cert Manager)"
echo "2. Storage (local-path provisioner)"
echo "3. Authentication (Authentik)"
echo "4. Monitoring Stack"
echo "5. Media Services"