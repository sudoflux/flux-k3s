# CRITICAL: Prometheus Security Status

## ⚠️ IMMEDIATE ACTION REQUIRED ⚠️

**Date**: June 16, 2025  
**Time**: 01:05 UTC  
**Status**: Prometheus is PUBLICLY EXPOSED without authentication  
**Risk Level**: HIGH - System metrics and sensitive data accessible  

## Current Situation

### ✅ Progress Made
1. **OAuth2-Proxy DNS Issue RESOLVED**
   - Added hostAlias to resolve authentik.fletcherlabs.net internally
   - OAuth2-Proxy can now reach Authentik
   - Getting expected 404 (OAuth2 provider not yet configured)

2. **Authentik Status**
   - Service is running and accessible
   - Admin interface responds with 200 OK
   - Ready for OAuth2 provider configuration

### 🔴 Blocking Issues
1. **Authentik OAuth2 Provider Not Configured**
   - Need to access https://authentik.fletcherlabs.net
   - Create OAuth2 provider for Prometheus
   - Get client secret for OAuth2-Proxy

2. **Prometheus Still Exposed**
   - Accessible at https://prometheus.fletcherlabs.net
   - NO AUTHENTICATION
   - Contains sensitive cluster metrics

## Required Actions (In Order)

### Step 1: Access Authentik Admin
```bash
# Open in browser
https://authentik.fletcherlabs.net

# If not initialized:
- Create admin user (username: akadmin)
- NO 2FA (per CIO directive)
- Save password securely

# If already initialized:
- Login with existing admin credentials
```

### Step 2: Create OAuth2 Provider in Authentik
1. Navigate to: Applications → Providers → Create
2. Select: OAuth2/OpenID Provider
3. Configure:
   - Name: `prometheus-provider`
   - Authorization flow: `default-provider-authorization-implicit-consent`
   - Client type: `Confidential`
   - Client ID: `prometheus`
   - Client Secret: **COPY THIS VALUE**
   - Redirect URIs: `https://prometheus.fletcherlabs.net/oauth2/callback`
   - Scopes: `openid profile email`
4. Save

### Step 3: Create Application in Authentik
1. Navigate to: Applications → Applications → Create
2. Configure:
   - Name: `Prometheus`
   - Slug: `prometheus`
   - Provider: `prometheus-provider`
   - Launch URL: `https://prometheus.fletcherlabs.net`
3. Save

### Step 4: Update OAuth2-Proxy Secret
```bash
# Encode the client secret from Authentik
CLIENT_SECRET="<paste-secret-from-authentik>"
echo -n "$CLIENT_SECRET" | base64

# Edit the secret file
vi /home/josh/flux-k3s/clusters/k3s-home/apps/monitoring/oauth2-proxy-prometheus/temp-secret.yaml

# Replace PLACEHOLDER_WILL_BE_UPDATED_AFTER_AUTHENTIK_SETUP with base64 encoded secret
# Save and exit

# Commit and push
cd /home/josh/flux-k3s
git add -A
git commit -m "feat: configure OAuth2-Proxy with Authentik credentials for Prometheus"
git push

# Force reconciliation
flux reconcile kustomization monitoring --with-source
```

### Step 5: Verify OAuth2-Proxy is Running
```bash
# Wait for pods to restart
sleep 30

# Check status (should be Running, not CrashLoopBackOff)
kubectl get pods -n monitoring -l app.kubernetes.io/name=oauth2-proxy

# Check logs (should show successful OIDC discovery)
kubectl logs -n monitoring -l app.kubernetes.io/name=oauth2-proxy --tail=20
```

### Step 6: Apply HTTPRoute to Secure Prometheus
```bash
# Only do this after OAuth2-Proxy is running successfully!
kubectl apply -f /home/josh/flux-k3s/clusters/k3s-home/apps/monitoring/oauth2-proxy-prometheus/prometheus-httproute-patch.yaml

# Verify
kubectl get httproute -n monitoring prometheus
```

### Step 7: Test Authentication
```bash
# Should redirect to Authentik login
curl -I https://prometheus.fletcherlabs.net

# In browser: Access https://prometheus.fletcherlabs.net
# Should redirect to Authentik login page
```

## Emergency Rollback
If something goes wrong and you need immediate Prometheus access:
```bash
# Revert to direct access (TEMPORARY ONLY!)
kubectl apply -f /home/josh/flux-k3s/clusters/k3s-home/apps/monitoring/kube-prometheus-stack/prometheus-httproute.yaml
```

## Time Estimate
- Total time to secure Prometheus: ~15 minutes
- Step 1-3 (Authentik setup): 5 minutes
- Step 4-5 (Secret update): 5 minutes
- Step 6-7 (Apply and test): 5 minutes

## Support Files
- Setup Guide: `/home/josh/flux-k3s/docs/authentik-prometheus-setup-guide.md`
- OAuth2 Templates: `/home/josh/flux-k3s/docs/oauth2-integration-templates.md`
- DNS Fix Status: `/home/josh/flux-k3s/docs/oauth2-proxy-dns-fix-status.md`

---
**REMEMBER**: Prometheus is currently exposing all cluster metrics without authentication. This is a critical security issue that must be resolved immediately!