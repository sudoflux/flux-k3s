# OAuth2-Proxy DNS Resolution Fix Status

## Date: June 16, 2025 (New Shift)

## Problem Solved
OAuth2-Proxy pods were failing to resolve `authentik.fletcherlabs.net` from inside the cluster, preventing OIDC discovery.

## Solution Applied
Added `hostAliases` to OAuth2-Proxy helm release to map `authentik.fletcherlabs.net` to the gateway IP `192.168.10.224`.

## Current Status
- ✅ OAuth2-Proxy pods can now reach Authentik
- ✅ Getting expected 404 error (OAuth2 provider not configured in Authentik yet)
- ✅ Authentik is running and accessible at https://authentik.fletcherlabs.net
- ⚠️ Prometheus still exposed without authentication

## Next Steps Required

### 1. Configure Authentik OAuth2 Provider
Access https://authentik.fletcherlabs.net and:
1. Login with admin credentials (if already created)
2. Create OAuth2 provider for Prometheus with:
   - Name: `prometheus-provider`
   - Client ID: `prometheus`
   - Redirect URI: `https://prometheus.fletcherlabs.net/oauth2/callback`
   - Copy the generated client secret

### 2. Update OAuth2-Proxy Secret
```bash
# Edit the temporary secret
vi clusters/k3s-home/apps/monitoring/oauth2-proxy-prometheus/temp-secret.yaml

# Update the client-secret with the value from Authentik
# The secret should be base64 encoded
echo -n "YOUR_CLIENT_SECRET" | base64
```

### 3. Commit and Apply
```bash
git add -A
git commit -m "feat: configure OAuth2-Proxy with Authentik client credentials"
git push
flux reconcile kustomization monitoring --with-source
```

### 4. Apply HTTPRoute Patch
Once OAuth2-Proxy pods are running successfully:
```bash
kubectl apply -f clusters/k3s-home/apps/monitoring/oauth2-proxy-prometheus/prometheus-httproute-patch.yaml
```

## Technical Notes
- The hostAlias fix is a temporary workaround
- Long-term solution should be CoreDNS configuration for internal hairpin resolution
- This pattern can be reused for other services needing to reach external domains internally

## Verification Commands
```bash
# Check OAuth2-Proxy status
kubectl get pods -n monitoring -l app.kubernetes.io/name=oauth2-proxy

# Watch logs for successful OIDC discovery
kubectl logs -n monitoring -l app.kubernetes.io/name=oauth2-proxy -f

# Test authentication after HTTPRoute is applied
curl -I https://prometheus.fletcherlabs.net
```