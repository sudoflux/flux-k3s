#!/bin/bash
# Automated OAuth2 deployment script for services

set -e

SERVICE_NAME="${1:-}"
SERVICE_URL="${2:-}"
SERVICE_NAMESPACE="${3:-}"

if [[ -z "$SERVICE_NAME" || -z "$SERVICE_URL" || -z "$SERVICE_NAMESPACE" ]]; then
    echo "Usage: $0 <service-name> <service-url> <namespace>"
    echo "Example: $0 longhorn longhorn.fletcherlabs.net longhorn-system"
    exit 1
fi

echo "🔧 Deploying OAuth2 authentication for $SERVICE_NAME..."

# Generate secure secrets
CLIENT_SECRET=$(openssl rand -hex 32)
COOKIE_SECRET=$(openssl rand -base64 32)

# Create OAuth2-Proxy directory
OAUTH_DIR="clusters/k3s-home/apps/${SERVICE_NAMESPACE}/oauth2-proxy-${SERVICE_NAME}"
mkdir -p "$OAUTH_DIR"

# Create kustomization.yaml
cat > "$OAUTH_DIR/kustomization.yaml" << EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: ${SERVICE_NAMESPACE}
resources:
  - helmrelease.yaml
  - temp-secret.yaml
  - httproute-patch.yaml
EOF

# Create HelmRelease
cat > "$OAUTH_DIR/helmrelease.yaml" << EOF
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: oauth2-proxy-${SERVICE_NAME}
  namespace: ${SERVICE_NAMESPACE}
spec:
  interval: 15m
  chart:
    spec:
      chart: oauth2-proxy
      version: "7.7.1"
      sourceRef:
        kind: HelmRepository
        name: oauth2-proxy
        namespace: flux-system
  values:
    config:
      existingSecret: oauth2-proxy-${SERVICE_NAME}-secret
      configFile: |-
        email_domains = [ "*" ]
        upstreams = [ "http://${SERVICE_NAME}-frontend:80" ]
        provider = "oidc"
        oidc_issuer_url = "https://authentik.fletcherlabs.net/application/o/${SERVICE_NAME}/"
        redirect_url = "https://${SERVICE_URL}/oauth2/callback"
        cookie_secure = true
        cookie_domains = [".fletcherlabs.net"]
        cookie_expire = "24h"
        cookie_refresh = "1h"
        skip_provider_button = true
        pass_authorization_header = true
        pass_access_token = true
        pass_user_headers = true
        set_authorization_header = true
        set_xauthrequest = true
        silence_ping_logging = true
        
    image:
      repository: quay.io/oauth2-proxy/oauth2-proxy
      tag: v7.6.0
      
    service:
      type: ClusterIP
      portNumber: 80
      
    resources:
      requests:
        cpu: 10m
        memory: 32Mi
      limits:
        cpu: 100m
        memory: 128Mi
        
    replicaCount: 2
    
    hostAliases:
      - ip: "192.168.10.224"
        hostnames:
          - "authentik.fletcherlabs.net"
    
    affinity:
      podAntiAffinity:
        preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                  - key: app.kubernetes.io/name
                    operator: In
                    values:
                      - oauth2-proxy
              topologyKey: kubernetes.io/hostname
EOF

# Create temporary secret (should be SOPS encrypted in production)
cat > "$OAUTH_DIR/temp-secret.yaml" << EOF
apiVersion: v1
kind: Secret
metadata:
  name: oauth2-proxy-${SERVICE_NAME}-secret
  namespace: ${SERVICE_NAMESPACE}
type: Opaque
stringData:
  client-id: "${SERVICE_NAME}"
  client-secret: "PLACEHOLDER_UPDATE_FROM_AUTHENTIK"
  cookie-secret: "${COOKIE_SECRET}"
EOF

# Create HTTPRoute patch
cat > "$OAUTH_DIR/httproute-patch.yaml" << EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: ${SERVICE_NAME}
  namespace: ${SERVICE_NAMESPACE}
spec:
  parentRefs:
    - name: main-gateway
      namespace: networking
      sectionName: https
  hostnames:
    - "${SERVICE_URL}"
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /oauth2
      backendRefs:
        - name: oauth2-proxy-${SERVICE_NAME}
          port: 80
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: oauth2-proxy-${SERVICE_NAME}
          port: 80
EOF

# Add to parent kustomization
echo "  - ./oauth2-proxy-${SERVICE_NAME}" >> "clusters/k3s-home/apps/${SERVICE_NAMESPACE}/kustomization.yaml"

echo "✅ OAuth2-Proxy files created for $SERVICE_NAME"
echo ""
echo "📋 Next steps:"
echo "1. Go to Authentik: https://authentik.fletcherlabs.net"
echo "2. Create OAuth2 Provider:"
echo "   - Name: ${SERVICE_NAME}-provider"
echo "   - Client ID: ${SERVICE_NAME}"
echo "   - Redirect URI: https://${SERVICE_URL}/oauth2/callback"
echo "3. Create Application:"
echo "   - Name: ${SERVICE_NAME^}"
echo "   - Slug: ${SERVICE_NAME}"
echo "   - Provider: ${SERVICE_NAME}-provider"
echo "4. Copy the client secret and update:"
echo "   vi $OAUTH_DIR/temp-secret.yaml"
echo "5. Commit and push:"
echo "   git add -A && git commit -m 'feat: add OAuth2 authentication for ${SERVICE_NAME}' && git push"
echo "6. Force reconciliation:"
echo "   flux reconcile kustomization ${SERVICE_NAMESPACE} --with-source"
echo ""
echo "🔐 Generated cookie secret: ${COOKIE_SECRET}"