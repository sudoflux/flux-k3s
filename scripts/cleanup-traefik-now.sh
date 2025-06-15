#!/bin/bash
# Quick cleanup script for Traefik resources causing log noise

set -euo pipefail

echo "=== Quick Traefik Cleanup ==="
echo

# Delete HelmChart resources which are causing the install loop
echo "1. Deleting Traefik HelmChart resources..."
kubectl delete helmchart traefik -n kube-system --ignore-not-found=true
kubectl delete helmchart traefik-crd -n kube-system --ignore-not-found=true

# Delete the failing pod
echo "2. Deleting failing Traefik installation pod..."
kubectl delete pod -n kube-system -l name=helm-install-traefik --ignore-not-found=true

# Check for any other Traefik resources
echo "3. Checking for remaining Traefik resources..."
kubectl get all -A | grep traefik || echo "No Traefik resources found"

echo
echo "Cleanup complete. The log noise should stop now."
echo
echo "To permanently disable Traefik, run: ./scripts/disable-traefik.sh"