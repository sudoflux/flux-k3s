#!/bin/bash
# Script to configure OAuth2 provider for Prometheus in Authentik
set -e

echo "=== Authentik OAuth2 Provider Setup for Prometheus ==="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check prerequisites
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Error: kubectl is not installed${NC}"
    exit 1
fi

if ! command -v sops &> /dev/null; then
    echo -e "${RED}Error: sops is not installed${NC}"
    exit 1
fi

# Check Authentik is running
echo "Checking Authentik status..."
AUTHENTIK_POD=$(kubectl get pods -n authentik -l app.kubernetes.io/component=server -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -z "$AUTHENTIK_POD" ]; then
    echo -e "${RED}Error: Authentik server pod not found${NC}"
    exit 1
fi

echo -e "${GREEN}Found Authentik server pod: $AUTHENTIK_POD${NC}"

# Generate secure client secret
CLIENT_SECRET=$(openssl rand -base64 48 | tr -d "=+/" | cut -c1-64)
echo -e "${YELLOW}Generated secure client secret${NC}"

# Create provider configuration
echo ""
echo -e "${YELLOW}Please complete the following steps:${NC}"
echo ""
echo "1. Access Authentik admin interface:"
echo "   ${GREEN}https://authentik.fletcherlabs.net${NC}"
echo ""
echo "2. Login with your admin credentials (username: akadmin)"
echo ""
echo "3. Navigate to: Applications → Providers → Create"
echo ""
echo "4. Select 'OAuth2/OpenID Provider' and configure with these EXACT values:"
echo "   ${GREEN}Name:${NC} prometheus-provider"
echo "   ${GREEN}Authorization flow:${NC} default-provider-authorization-implicit-consent"
echo "   ${GREEN}Client type:${NC} Confidential"
echo "   ${GREEN}Client ID:${NC} prometheus"
echo "   ${GREEN}Client Secret:${NC} $CLIENT_SECRET"
echo "   ${GREEN}Redirect URIs:${NC} https://prometheus.fletcherlabs.net/oauth2/callback"
echo "   ${GREEN}Scopes:${NC} openid profile email"
echo ""
echo "5. Click 'Save'"
echo ""
echo "6. Navigate to: Applications → Applications → Create"
echo ""
echo "7. Configure the application:"
echo "   ${GREEN}Name:${NC} Prometheus"
echo "   ${GREEN}Slug:${NC} prometheus"
echo "   ${GREEN}Provider:${NC} prometheus-provider"
echo "   ${GREEN}Launch URL:${NC} https://prometheus.fletcherlabs.net"
echo ""
echo "8. Click 'Save'"
echo ""
echo -e "${YELLOW}Press Enter when you have completed the above steps...${NC}"
read -p ""

# Update the secret file
echo -e "\n${YELLOW}Updating OAuth2 proxy secret...${NC}"

# Create temporary secret file with real values
cat > /tmp/oauth2-secret.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
    name: oauth2-proxy-prometheus-secret
    namespace: monitoring
type: Opaque
stringData:
    client-id: prometheus
    client-secret: $CLIENT_SECRET
    cookie-secret: $(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)
EOF

# Encrypt with sops
echo "Encrypting secret with SOPS..."
sops -e -i /tmp/oauth2-secret.yaml

# Backup existing secret
cp /home/josh/flux-k3s/clusters/k3s-home/apps/monitoring/oauth2-proxy-prometheus/secret.yaml \
   /home/josh/flux-k3s/clusters/k3s-home/apps/monitoring/oauth2-proxy-prometheus/secret.yaml.bak

# Replace with new encrypted secret
mv /tmp/oauth2-secret.yaml /home/josh/flux-k3s/clusters/k3s-home/apps/monitoring/oauth2-proxy-prometheus/secret.yaml

echo -e "${GREEN}Secret updated successfully!${NC}"

# Apply changes
echo -e "\n${YELLOW}Applying configuration...${NC}"
cd /home/josh/flux-k3s

# Commit changes
git add clusters/k3s-home/apps/monitoring/oauth2-proxy-prometheus/secret.yaml
git commit -m "feat: configure OAuth2 authentication for Prometheus

- Update oauth2-proxy secret with real Authentik credentials
- Enable secure access to Prometheus via Authentik SSO

🤖 Generated with Claude Code

Co-Authored-By: Claude <noreply@anthropic.com>"

# Push changes
git push

echo -e "\n${YELLOW}Waiting for Flux to reconcile...${NC}"
flux reconcile source git flux-system
flux reconcile kustomization monitoring

# Re-enable oauth2-proxy
echo -e "\n${YELLOW}Re-enabling OAuth2 proxy...${NC}"
kubectl scale deployment oauth2-proxy-prometheus -n monitoring --replicas=2

# Wait for pods to be ready
echo "Waiting for OAuth2 proxy pods to start..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=oauth2-proxy -n monitoring --timeout=120s || true

# Check status
echo -e "\n${GREEN}=== Current Status ===${NC}"
kubectl get pods -n monitoring -l app.kubernetes.io/name=oauth2-proxy

echo -e "\n${GREEN}=== Setup Complete ===${NC}"
echo ""
echo "Next steps:"
echo "1. Test access to ${GREEN}https://prometheus.fletcherlabs.net${NC}"
echo "2. You should be redirected to Authentik for login"
echo "3. After login, you'll be redirected back to Prometheus"
echo ""
echo -e "${YELLOW}If you encounter issues, check logs with:${NC}"
echo "kubectl logs -n monitoring -l app.kubernetes.io/name=oauth2-proxy --tail=50"