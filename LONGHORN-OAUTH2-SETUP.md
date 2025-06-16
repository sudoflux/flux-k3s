# Longhorn OAuth2 Setup - Ready for Completion

## Status
✅ All Kubernetes manifests created and committed to Git  
⏳ Waiting for Authentik configuration  
🔐 Longhorn is still using basic auth (not yet switched to OAuth2)

## Quick Setup Instructions (5 minutes)

When you return, complete these steps:

### 1. Access Authentik
Go to: https://authentik.fletcherlabs.net  
Login with your admin credentials

### 2. Create OAuth2 Provider
- Click **Applications** → **Providers** → **Create**
- Select **OAuth2/OpenID Provider**
- Configure:
  ```
  Name: longhorn-provider
  Authentication flow: default-authentication-flow
  Authorization flow: default-provider-authorization-implicit-consent
  Client type: Confidential
  Client ID: longhorn
  Client Secret: [CLICK REGENERATE AND COPY]
  Redirect URIs: https://longhorn.fletcherlabs.net/oauth2/callback
  Scopes: openid profile email
  ```
- Click **Save** and **COPY THE CLIENT SECRET**

### 3. Create Application
- Click **Applications** → **Applications** → **Create**
- Configure:
  ```
  Name: Longhorn UI
  Slug: longhorn
  Provider: longhorn-provider (select from dropdown)
  Launch URL: https://longhorn.fletcherlabs.net
  ```
- Click **Save**

### 4. Update Client Secret
```bash
# Edit the secret file
vi /home/josh/flux-k3s/clusters/k3s-home/apps/longhorn-system/oauth2-proxy-longhorn/temp-secret.yaml

# Replace PLACEHOLDER_UPDATE_FROM_AUTHENTIK with your actual client secret
# Keep the quotes: client-secret: "your-actual-secret-here"
```

### 5. Deploy OAuth2-Proxy
```bash
# Commit and push
git add -A
git commit -m "feat: configure OAuth2 client secret for Longhorn"
git push

# Force reconciliation
flux reconcile kustomization longhorn-system --with-source

# Wait for deployment (about 1 minute)
sleep 60

# Check if OAuth2-Proxy is running
kubectl get pods -n longhorn-system -l app.kubernetes.io/name=oauth2-proxy
```

### 6. Test Access
- Go to https://longhorn.fletcherlabs.net
- You should be redirected to Authentik for login
- After login, you'll be redirected back to Longhorn UI

## What Was Prepared

### Files Created:
- `/clusters/k3s-home/apps/longhorn-system/oauth2-proxy-longhorn/helmrelease.yaml` - OAuth2-Proxy deployment
- `/clusters/k3s-home/apps/longhorn-system/oauth2-proxy-longhorn/temp-secret.yaml` - Credentials (needs client secret)
- `/clusters/k3s-home/apps/longhorn-system/oauth2-proxy-longhorn/httproute-patch.yaml` - Gateway routing
- `/clusters/k3s-home/apps/longhorn-system/oauth2-proxy-longhorn/kustomization.yaml` - Kustomize config

### Already Configured:
- ✅ Cookie secret generated
- ✅ DNS workaround (hostAlias) included
- ✅ OIDC issuer URL with trailing slash
- ✅ HTTPRoute ready to redirect to OAuth2-Proxy
- ✅ All manifests committed to Git

### Security Notes:
- Longhorn is currently still accessible with basic auth
- Once OAuth2 is configured, all users will need to authenticate through Authentik
- The basic auth will be automatically replaced by OAuth2

## If Something Goes Wrong

### OAuth2-Proxy Won't Start:
```bash
# Check logs
kubectl logs -n longhorn-system -l app.kubernetes.io/name=oauth2-proxy --tail=50

# Common issues:
# - Wrong client secret
# - OIDC discovery failing (check Authentik is accessible)
```

### Need to Rollback:
```bash
# Remove OAuth2-Proxy from kustomization
vi /home/josh/flux-k3s/clusters/k3s-home/apps/longhorn-system/kustomization.yaml
# Remove the line: - ./oauth2-proxy-longhorn

# Commit and push
git add -A && git commit -m "revert: remove OAuth2 from Longhorn" && git push
```

---
**Prepared by**: Claude Opus 4  
**Time**: June 16, 2025 03:30 UTC  
**Status**: Ready for Authentik configuration