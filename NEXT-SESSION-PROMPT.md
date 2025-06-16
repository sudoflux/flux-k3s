# Next Session Prompt - K3s Homelab Cluster

## Session Context
**Date**: June 16, 2025 (Night Shift Handover)  
**Critical Issue**: Prometheus exposed without authentication - OAuth2-Proxy deployed, awaiting Authentik config  
**Immediate Priority**: Complete Authentik setup and secure Prometheus IMMEDIATELY

## Today's Achievements

### Infrastructure Recovery Complete
- ✅ Longhorn v1.6.2 fresh install working perfectly
- ✅ Monitoring stack on persistent storage (local-path workaround for fsGroup issues)
- ✅ Velero backups to Backblaze B2 configured and tested
- ✅ All media and AI workloads running smoothly

### Monitoring Improvements
- ✅ Comprehensive Longhorn health alerts configured
- ✅ Alert templates for clear, actionable notifications
- ✅ Prometheus accessible at https://prometheus.fletcherlabs.net (NO AUTH!)
- ✅ Coverage for volume health, node storage, disk capacity, CSI status

### Security Preparations
- ✅ Authentik deployed at https://authentik.fletcherlabs.net
- ✅ OAuth2-Proxy deployed and configured for Prometheus (awaiting Authentik setup)
- ✅ OAuth2-Proxy templates ready for other services (Longhorn, Grafana, etc.)
- ✅ SOPS encryption working for all secrets
- ✅ Documentation for Traefik removal (not executed)

### OAuth2-Proxy Deployment (Night Shift)
- ✅ Successfully deployed OAuth2-Proxy for Prometheus
- ✅ Fixed multiple technical issues:
  - Helm chart compatibility (service.port → service.portNumber)
  - Cookie secret length (must be exactly 32 bytes)
  - OIDC issuer URL format (no trailing slash)
- ✅ Created comprehensive setup documentation
- ⚠️ Using temporary plain secret due to SOPS issue (investigate later)

## Current Cluster State

### Working Services
```bash
# All services accessible via HTTPS
https://longhorn.fletcherlabs.net     # Storage UI
https://grafana.fletcherlabs.net      # Monitoring dashboards (has auth)
https://prometheus.fletcherlabs.net   # ⚠️ EXPOSED - NO AUTH (OAuth2-Proxy ready)
https://authentik.fletcherlabs.net    # Auth system (needs setup)
https://*.fletcherlabs.net           # All media/AI services working
```

### OAuth2-Proxy Status
- Deployment: Running in monitoring namespace
- Current Error: 404 on OIDC discovery (EXPECTED - Authentik not configured)
- Ready to secure Prometheus once Authentik is configured

### Storage Status
- Longhorn: Fully operational on all nodes
- Storage Classes: longhorn, longhorn-nvme, longhorn-optane, longhorn-sas-ssd
- NFS: Working for bulk media storage
- Local-path: Used for monitoring due to fsGroup issues

### Backup Status
- Velero: Configured with Backblaze B2
- Schedules: Hourly (Longhorn), Daily (critical), Weekly (full)
- MinIO local storage: Broken but not critical

## 🔴 CRITICAL - Immediate Actions Required

### 1. Complete Authentik Setup (15 minutes)
```bash
# 1. Access Authentik
https://authentik.fletcherlabs.net

# 2. Follow the setup guide
cat docs/authentik-prometheus-setup-guide.md

# Key steps:
- Create initial admin (NO 2FA per CIO directive)
- Create OAuth2 provider for Prometheus
- Copy the client secret
```

### 2. Update OAuth2-Proxy Secret (5 minutes)
```bash
# Edit the temporary secret with actual client secret from Authentik
vi clusters/k3s-home/apps/monitoring/oauth2-proxy-prometheus/temp-secret.yaml

# Update client-secret field with value from Authentik
# Commit and push
git add -A && git commit -m "feat: configure OAuth2-Proxy with Authentik credentials" && git push

# Force reconciliation
flux reconcile kustomization monitoring --with-source
```

### 3. Apply HTTPRoute to Secure Prometheus (2 minutes)
```bash
# Once OAuth2-Proxy is working (check pods first)
kubectl get pods -n monitoring -l app.kubernetes.io/name=oauth2-proxy

# Apply the HTTPRoute patch
kubectl apply -f clusters/k3s-home/apps/monitoring/oauth2-proxy-prometheus/prometheus-httproute-patch.yaml

# Test authentication
curl -I https://prometheus.fletcherlabs.net
# Should redirect to Authentik login
```

## Remaining Priorities

### 🟡 Priority 1 - This Week
1. **Complete OAuth2 Integration**
   - Longhorn UI (currently using basic auth)
   - Grafana (enhance existing auth)
   - All other sensitive services

2. **Fix SOPS Issue**
   - OAuth2-Proxy secret not decrypting
   - Currently using plain secret as workaround
   - Other secrets in same namespace work fine

3. **Test Monitoring Alerts**
   - Verify Longhorn alerts fire correctly
   - Configure external notification channels
   - Test backup failure alerts

### 🟢 Priority 2 - When Time Permits
4. **Disable K3s Traefik**
   ```bash
   # SSH to master node
   ssh josh@192.168.10.30
   
   # Run disable script
   /home/josh/flux-k3s/scripts/disable-traefik.sh
   ```

5. **Fix MinIO Local Storage**
   - Investigate "0 drives provided" error
   - Not critical - B2 backups working

## Quick Reference Commands

### Check OAuth2-Proxy Status
```bash
# Pod status
kubectl get pods -n monitoring -l app.kubernetes.io/name=oauth2-proxy

# Logs (will show OIDC errors until Authentik configured)
kubectl logs -n monitoring -l app.kubernetes.io/name=oauth2-proxy --tail=50

# Restart if needed
kubectl rollout restart deployment oauth2-proxy-prometheus -n monitoring
```

### Emergency Procedures
```bash
# If you need immediate Prometheus access (TEMPORARY ONLY!)
kubectl apply -f clusters/k3s-home/apps/monitoring/kube-prometheus-stack/prometheus-httproute.yaml

# Check Flux sync
flux get all -A | grep -E "(oauth2|monitoring)"
```

## Important Security Considerations

### ⚠️ CRITICAL: Exposed Services
1. **Prometheus is publicly accessible without authentication**
   - Contains sensitive system metrics
   - OAuth2-Proxy is deployed and ready
   - Just needs Authentik configuration to activate

### SOPS Encryption Issue
- OAuth2-Proxy secret using plain text temporarily
- Age key location: `~/.config/sops/age/keys.txt`
- Need to investigate why SOPS isn't decrypting in monitoring namespace

## Key Documentation
- **Step-by-step guide**: `docs/authentik-prometheus-setup-guide.md`
- **OAuth2-Proxy status**: `docs/oauth2-proxy-status-2025-06-15.md`
- **OAuth2 templates**: `docs/oauth2-integration-templates.md`
- **Main overview**: `CLUSTER-SETUP.md`

## Technical Gotchas Discovered
1. OAuth2-Proxy helm chart v7.7.1 uses `service.portNumber` not `service.port`
2. Cookie secret MUST be exactly 16, 24, or 32 bytes (we use 32)
3. Authentik OIDC issuer URLs don't have trailing slashes
4. SOPS decryption needs to be explicitly configured per kustomization

## Notes for Next Team
1. OAuth2-Proxy is READY - just complete Authentik setup
2. The setup guide has exact copy-paste instructions
3. Once Prometheus is secured, use same pattern for other services
4. Don't forget to investigate the SOPS issue when time permits
5. All OAuth2 templates are tested and ready to deploy

---
**Remember**: First priority is securing Prometheus. Everything is deployed and ready - just needs Authentik configuration!