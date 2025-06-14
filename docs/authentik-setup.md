# Authentik SSO Setup Documentation

## Overview
This document captures the SSO configuration for Authentik in the K3s cluster.

## Access Information
- **URL**: https://authentik.fletcherlabs.net
- **Admin Account**: To be created on first deployment
- **2FA**: DISABLED per CIO directive until 30-day stability period

## Deployment Status
As of 2025-06-14, Authentik deployment is pending due to infrastructure dependencies. 

### Current Issues:
1. The `auth` kustomization depends on `infra-runtime` which is not ready
2. Cascade dependency chain: infra-runtime → infra-intel-gpu → infra-nfd

### Manual Deployment Steps (if needed):
```bash
# 1. Create namespace
kubectl apply -f /home/josh/flux-k3s/clusters/k3s-home/apps/auth/namespace.yaml

# 2. Apply secrets
sops -d /home/josh/flux-k3s/clusters/k3s-home/apps/auth/authentik/secret-authentik.yaml | kubectl apply -f -

# 3. Deploy PostgreSQL
helm install authentik-postgresql bitnami/postgresql \
  --namespace authentik \
  --version 14.0.5 \
  --values <(sops -d /home/josh/flux-k3s/clusters/k3s-home/apps/auth/authentik/secret-authentik.yaml | yq '.data.values' | base64 -d | yq '.postgresql')

# 4. Deploy Redis  
helm install authentik-redis bitnami/redis \
  --namespace authentik \
  --version 18.6.1 \
  --values <(sops -d /home/josh/flux-k3s/clusters/k3s-home/apps/auth/authentik/secret-authentik.yaml | yq '.data.values' | base64 -d | yq '.redis')

# 5. Deploy Authentik
helm install authentik authentik/authentik \
  --namespace authentik \
  --version 2023.10.7 \
  --values <(sops -d /home/josh/flux-k3s/clusters/k3s-home/apps/auth/authentik/secret-authentik.yaml | yq '.data.values' | base64 -d | yq '.authentik')
```

## OAuth2 Provider Configuration

### 1. Grafana Integration
- **Provider Type**: OAuth2/OpenID Connect
- **Client ID**: `grafana`
- **Redirect URI**: `https://grafana.fletcherlabs.net/login/generic_oauth`
- **Scopes**: `openid profile email`

### 2. Jellyfin Integration  
- **Provider Type**: OAuth2/OpenID Connect
- **Client ID**: `jellyfin`
- **Redirect URI**: `https://jellyfin.fletcherlabs.net/sso/OID/redirect/authentik`
- **Scopes**: `openid profile email`

### 3. Open-WebUI Integration
- **Provider Type**: OAuth2/OpenID Connect  
- **Client ID**: `open-webui`
- **Redirect URI**: `https://open-webui.fletcherlabs.net/auth/oauth/callback`
- **Scopes**: `openid profile email`

## Application Configuration Updates

### Grafana
Add to Grafana values:
```yaml
grafana.ini:
  auth.generic_oauth:
    enabled: true
    name: Authentik
    allow_sign_up: true
    client_id: grafana
    client_secret: <from-authentik>
    scopes: openid profile email
    auth_url: https://authentik.fletcherlabs.net/application/o/authorize/
    token_url: https://authentik.fletcherlabs.net/application/o/token/
    api_url: https://authentik.fletcherlabs.net/application/o/userinfo/
```

### Jellyfin
Configure through Jellyfin Admin Dashboard:
1. Navigate to Dashboard → Plugins → SSO Authentication
2. Add OAuth provider with Authentik details

### Open-WebUI
Set environment variables:
```yaml
OAUTH_ENABLED: "true"
OAUTH_PROVIDER_NAME: "Authentik"
OAUTH_CLIENT_ID: "open-webui"
OAUTH_CLIENT_SECRET: "<from-authentik>"
OAUTH_AUTHORIZATION_URL: "https://authentik.fletcherlabs.net/application/o/authorize/"
OAUTH_TOKEN_URL: "https://authentik.fletcherlabs.net/application/o/token/"
OAUTH_USERINFO_URL: "https://authentik.fletcherlabs.net/application/o/userinfo/"
```

## Security Notes
- 2FA is DISABLED per executive mandate until cluster achieves 30-day stability
- All OAuth2 flows use HTTPS exclusively
- Client secrets stored in SOPS-encrypted secrets

## Troubleshooting
If Authentik is not accessible:
1. Check pod status: `kubectl get pods -n authentik`
2. Check ingress: `kubectl get httproute -n authentik`
3. Verify secrets: `kubectl get secrets -n authentik`
4. Check logs: `kubectl logs -n authentik -l app.kubernetes.io/name=authentik`