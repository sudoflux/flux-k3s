# Next Session Prompt - K3s Homelab Cluster

## Session Context
**Date**: June 16, 2025 (Early Morning Handover)  
**Critical Issue**: Prometheus STILL exposed without authentication - OAuth2-Proxy ready and waiting  
**Immediate Priority**: Access Authentik and complete OAuth2 configuration NOW  

## ⚠️ CRITICAL SECURITY ALERT ⚠️
Prometheus is publicly accessible at https://prometheus.fletcherlabs.net exposing all cluster metrics without authentication. OAuth2-Proxy is deployed and ready - just needs Authentik configuration.

## Today's Achievements

### OAuth2-Proxy DNS Resolution Fixed ✅
- **Problem**: Pods couldn't resolve authentik.fletcherlabs.net internally
- **Solution**: Added hostAlias to map domain to gateway IP (192.168.10.224)
- **Result**: OAuth2-Proxy now successfully reaches Authentik
- **Status**: Getting expected 404 - OAuth2 provider not configured yet

### Documentation Created ✅
- **CURRENT-CRITICAL-STATUS.md**: Step-by-step guide with exact commands
- **oauth2-proxy-dns-fix-status.md**: Technical details of the DNS fix
- **Updated CLUSTER-SETUP.md**: Current status and new AAR entry

## Current Cluster State

### 🔴 EXPOSED Services
```bash
https://prometheus.fletcherlabs.net   # NO AUTHENTICATION - Critical Risk!
```

### ✅ Protected Services
```bash
https://longhorn.fletcherlabs.net     # Basic auth
https://grafana.fletcherlabs.net      # Has authentication
https://authentik.fletcherlabs.net    # Ready for configuration
```

### OAuth2-Proxy Status
- **Deployment**: Running with hostAlias DNS fix
- **Current State**: Waiting for Authentik OAuth2 provider
- **Expected Error**: 404 on OIDC discovery (normal - provider doesn't exist yet)
- **Next Step**: Create provider in Authentik

## 🚨 IMMEDIATE ACTIONS REQUIRED (15 minutes total)

### Step 1: Open Authentik (2 minutes)
```bash
# In your browser, go to:
https://authentik.fletcherlabs.net

# You should see either:
# - Initial setup page (create admin account)
# - Login page (admin already exists)
```

### Step 2: Initial Setup or Login (3 minutes)
**If Initial Setup Page:**
- Username: `akadmin`
- Email: Your admin email
- Password: Strong password (save it!)
- **NO 2FA** (per CIO directive)

**If Login Page:**
- Login with existing admin credentials
- If you don't have them, check with team

### Step 3: Create OAuth2 Provider (5 minutes)
1. Navigate to: **Applications** → **Providers** → **Create**
2. Select: **OAuth2/OpenID Provider**
3. Configure EXACTLY as shown:
   ```
   Name: prometheus-provider
   Authorization flow: default-provider-authorization-implicit-consent
   Client type: Confidential
   Client ID: prometheus
   Client Secret: [COPY THE GENERATED SECRET]
   Redirect URIs: https://prometheus.fletcherlabs.net/oauth2/callback
   Scopes: openid profile email
   ```
4. Click **Save**
5. **COPY THE CLIENT SECRET** - You need it for Step 5!

### Step 4: Create Application (2 minutes)
1. Navigate to: **Applications** → **Applications** → **Create**
2. Configure:
   ```
   Name: Prometheus
   Slug: prometheus
   Provider: prometheus-provider
   Launch URL: https://prometheus.fletcherlabs.net
   ```
3. Click **Save**

### Step 5: Update OAuth2-Proxy Secret (3 minutes)
```bash
# In terminal, navigate to repo
cd /home/josh/flux-k3s

# Edit the secret file
vi clusters/k3s-home/apps/monitoring/oauth2-proxy-prometheus/temp-secret.yaml

# Find the line:
#   client-secret: "PLACEHOLDER_WILL_BE_UPDATED_AFTER_AUTHENTIK_SETUP"
# Replace with:
#   client-secret: "<paste-secret-from-step-3>"

# Save and exit (:wq)

# Commit and push
git add -A
git commit -m "feat: configure OAuth2-Proxy with Authentik credentials"
git push

# Force reconciliation
flux reconcile kustomization monitoring --with-source
```

### Step 6: Verify OAuth2-Proxy Running (1 minute)
```bash
# Wait for pods to restart
sleep 30

# Check status - should show Running, not CrashLoopBackOff
kubectl get pods -n monitoring -l app.kubernetes.io/name=oauth2-proxy

# Verify logs show successful OIDC discovery
kubectl logs -n monitoring -l app.kubernetes.io/name=oauth2-proxy --tail=10
```

### Step 7: Apply HTTPRoute to Secure Prometheus (1 minute)
```bash
# ONLY after OAuth2-Proxy is running successfully!
kubectl apply -f clusters/k3s-home/apps/monitoring/oauth2-proxy-prometheus/prometheus-httproute-patch.yaml

# Test - should redirect to Authentik login
curl -I https://prometheus.fletcherlabs.net
```

## If Something Goes Wrong

### OAuth2-Proxy Still Crashing?
```bash
# Check exact error
kubectl logs -n monitoring -l app.kubernetes.io/name=oauth2-proxy --tail=50

# Common issues:
# - Client secret mismatch
# - Typo in redirect URI
# - Provider not saved in Authentik
```

### Need Immediate Prometheus Access?
```bash
# TEMPORARY rollback (security risk!)
kubectl apply -f clusters/k3s-home/apps/monitoring/kube-prometheus-stack/prometheus-httproute.yaml
```

## After Prometheus is Secured

### Priority Tasks
1. **Configure OAuth2 for Longhorn** - Template ready in `docs/oauth2-integration-templates.md`
2. **Fix SOPS decryption** - OAuth2-Proxy secret should be encrypted
3. **CoreDNS hairpin solution** - Replace temporary hostAlias fix
4. **Test monitoring alerts** - Verify Longhorn health alerts work

### Technical Debt
- OAuth2-Proxy using temporary plain secret (SOPS not decrypting)
- DNS resolution using hostAlias workaround (need CoreDNS fix)
- MinIO local storage broken (B2 backups working fine)
- Traefik still trying to install (just log noise)

## Key Files & Documentation
- **Urgent Guide**: `CURRENT-CRITICAL-STATUS.md`
- **Setup Guide**: `docs/authentik-prometheus-setup-guide.md`
- **OAuth2 Templates**: `docs/oauth2-integration-templates.md`
- **DNS Fix Details**: `docs/oauth2-proxy-dns-fix-status.md`

## Commands Quick Reference
```bash
# Check OAuth2-Proxy status
kubectl get pods -n monitoring -l app.kubernetes.io/name=oauth2-proxy

# Watch logs
kubectl logs -n monitoring -l app.kubernetes.io/name=oauth2-proxy -f

# Check HTTPRoute
kubectl get httproute -n monitoring prometheus

# Force Flux sync
flux reconcile kustomization monitoring --with-source
```

---
**Remember**: Prometheus is exposing sensitive cluster metrics RIGHT NOW. This is your #1 priority!