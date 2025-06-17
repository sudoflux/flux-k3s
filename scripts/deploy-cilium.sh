#!/bin/bash
# Deploy Cilium CNI for K3s
# June 16, 2025

set -euo pipefail

echo "=== Deploying Cilium CNI ==="

# Wait for nodes to be ready (without CNI they'll be NotReady)
echo "Checking node status..."
kubectl get nodes

# Install Cilium CLI if not present
if ! command -v cilium &> /dev/null; then
    echo "Installing Cilium CLI..."
    CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
    CLI_ARCH=amd64
    if [ "$(uname -m)" = "aarch64" ]; then CLI_ARCH=arm64; fi
    curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
    sha256sum --check cilium-linux-${CLI_ARCH}.tar.gz.sha256sum
    sudo tar xzvfC cilium-linux-${CLI_ARCH}.tar.gz /usr/local/bin
    rm cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
fi

# Deploy Cilium with Gateway API
echo "Deploying Cilium..."
cilium install \
  --version 1.16.5 \
  --set operator.replicas=1 \
  --set kubeProxyReplacement=true \
  --set gatewayAPI.enabled=true \
  --set bgpControlPlane.enabled=true \
  --set k8sServiceHost=192.168.10.30 \
  --set k8sServicePort=6443

echo "Waiting for Cilium to be ready..."
cilium status --wait

echo "Cilium deployed successfully!"
echo ""
echo "Next steps:"
echo "1. Verify all nodes are Ready: kubectl get nodes"
echo "2. Deploy Gateway API CRDs: kubectl apply -f clusters/k3s-home/infrastructure/00-gateway-api/"
echo "3. Bootstrap Flux: ./scripts/bootstrap-flux.sh"