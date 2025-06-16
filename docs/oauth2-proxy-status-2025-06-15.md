# OAuth2-Proxy Deployment Status

## Date: June 15, 2025 (Night Shift)

## Current Status

### ✅ Completed
1. OAuth2-Proxy Helm repository added to Flux
2. OAuth2-Proxy deployment created with proper configuration
3. Fixed helm chart compatibility issues (service.port → service.portNumber)
4. Fixed cookie secret length (must be exactly 32 bytes)
5. Added SOPS decryption to monitoring kustomization
6. Created temporary plain secret workaround for testing
7. Fixed OIDC issuer URL format

### 🔄 In Progress
- OAuth2-Proxy is deployed but waiting for Authentik configuration
- Current error: "404" on OIDC discovery (expected - Authentik app not created yet)

### ⏳ Next Steps

#### Immediate Actions Required:
1. **Access Authentik UI** at https://authentik.fletcherlabs.net
   - Complete initial admin setup (NO 2FA per directive)
   - Create OAuth2 provider for Prometheus
   - Follow docs/authentik-prometheus-setup-guide.md

2. **Update OAuth2-Proxy Secret**
   - Get client secret from Authentik after provider creation
   - Update temp-secret.yaml with actual client secret
   - Commit and push changes

3. **Apply HTTPRoute Update**
   - Apply prometheus-httproute-patch.yaml to route through OAuth2-Proxy
   - This will secure Prometheus behind authentication

## Technical Details

### OAuth2-Proxy Configuration
- **Namespace**: monitoring
- **Service**: oauth2-proxy-prometheus:80
- **OIDC Issuer**: https://authentik.fletcherlabs.net/application/o/prometheus
- **Redirect URL**: https://prometheus.fletcherlabs.net/oauth2/callback
- **Cookie Domain**: .fletcherlabs.net (enables SSO across subdomains)

### Current Pod Status
```bash
# OAuth2-Proxy pods are running but failing OIDC discovery
# This is expected until Authentik is configured
kubectl logs -n monitoring -l app.kubernetes.io/name=oauth2-proxy
```

### SOPS Issue
- SOPS decryption was added to monitoring kustomization but secret wasn't being decrypted
- Using temporary plain secret as workaround
- Need to investigate why SOPS isn't decrypting in monitoring namespace
- Other secrets in same namespace (grafana-admin-credentials) decrypt properly

## Security Considerations

⚠️ **CRITICAL**: Prometheus is still publicly accessible at https://prometheus.fletcherlabs.net
- Contains sensitive cluster metrics
- Must complete Authentik setup ASAP
- HTTPRoute patch ready to apply once OAuth2-Proxy is working

## Files Created/Modified
1. `/clusters/k3s-home/infrastructure/sources/oauth2-proxy.yaml` - Helm repository
2. `/clusters/k3s-home/apps/monitoring/oauth2-proxy-prometheus/` - OAuth2-Proxy deployment
3. `/clusters/k3s-home/apps/monitoring-kustomization.yaml` - Added SOPS decryption
4. `/docs/authentik-prometheus-setup-guide.md` - Step-by-step setup guide

## Commands for Next Team

```bash
# Check OAuth2-Proxy status
kubectl get pods -n monitoring -l app.kubernetes.io/name=oauth2-proxy
kubectl logs -n monitoring -l app.kubernetes.io/name=oauth2-proxy --tail=50

# After Authentik setup, update secret
vi clusters/k3s-home/apps/monitoring/oauth2-proxy-prometheus/temp-secret.yaml
# Update client-secret with value from Authentik

# Apply HTTPRoute patch to secure Prometheus
kubectl apply -f clusters/k3s-home/apps/monitoring/oauth2-proxy-prometheus/prometheus-httproute-patch.yaml

# Test authentication
curl -I https://prometheus.fletcherlabs.net
# Should redirect to Authentik login
```

## Rollback Plan
If issues arise and immediate Prometheus access is needed:
```bash
# Revert to direct access (TEMPORARY ONLY!)
kubectl apply -f clusters/k3s-home/apps/monitoring/kube-prometheus-stack/prometheus-httproute.yaml
```

---
**Remember**: The priority is to secure Prometheus. It's currently exposing all cluster metrics without authentication!