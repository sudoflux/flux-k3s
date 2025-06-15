# Next Session Prompt - K3s Homelab Cluster

## Session Context
**Date**: June 15, 2025 (Evening)  
**Critical Issue**: Prometheus exposed without authentication  
**Immediate Priority**: Configure Authentik and secure monitoring endpoints

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
- ✅ OAuth2-Proxy templates ready for all services
- ✅ SOPS encryption working for all secrets
- ✅ Documentation for Traefik removal (not executed)

## Current Cluster State

### Working Services
```bash
# All services accessible via HTTPS
https://longhorn.fletcherlabs.net     # Storage UI
https://grafana.fletcherlabs.net      # Monitoring dashboards (has auth)
https://prometheus.fletcherlabs.net   # ⚠️ EXPOSED - NO AUTH
https://authentik.fletcherlabs.net    # Auth system (needs setup)
https://*.fletcherlabs.net           # All media/AI services working
```

### Storage Status
- Longhorn: Fully operational on all nodes
- Storage Classes: longhorn, longhorn-nvme, longhorn-optane, longhorn-sas-ssd
- NFS: Working for bulk media storage
- Local-path: Used for monitoring due to fsGroup issues

### Backup Status
- Velero: Configured with Backblaze B2
- Schedules: Hourly (Longhorn), Daily (critical), Weekly (full)
- MinIO local storage: Broken but not critical

## Remaining Priorities

### 🔴 Priority 0 - URGENT Security
1. **Configure Authentik**
   ```bash
   # Access Authentik
   https://authentik.fletcherlabs.net
   
   # Create initial admin (NO 2FA per CIO directive)
   # Follow: docs/authentik-manual-setup-steps.md
   ```

2. **Secure Prometheus**
   ```bash
   # Templates ready at:
   docs/oauth2-integration-templates.md
   
   # Deploy OAuth2-Proxy for Prometheus IMMEDIATELY
   # This is exposing sensitive metrics!
   ```

### 🟡 Priority 1 - This Week
3. **Complete OAuth2 Integration**
   - Longhorn UI (currently using basic auth)
   - Grafana (enhance existing auth)
   - All other sensitive services

4. **Test Monitoring Alerts**
   - Verify Longhorn alerts fire correctly
   - Configure external notification channels
   - Test backup failure alerts

### 🟢 Priority 2 - When Time Permits
5. **Disable K3s Traefik**
   ```bash
   # SSH to master node
   ssh josh@192.168.10.30
   
   # Run disable script
   /home/josh/flux-k3s/scripts/disable-traefik.sh
   ```

6. **Fix MinIO Local Storage**
   - Investigate "0 drives provided" error
   - Not critical - B2 backups working

## Quick Start Commands

### Check Cluster Health
```bash
# Node status
kubectl get nodes -o wide

# Storage health
kubectl get pvc -A
kubectl -n longhorn-system get volumes.longhorn.io

# Check backups
velero backup get
velero schedule get

# Check Flux sync
flux get all -A
```

### Access Key Services
```bash
# Monitoring (check alerts)
echo "Grafana: https://grafana.fletcherlabs.net"
echo "Prometheus: https://prometheus.fletcherlabs.net (NO AUTH!)"

# Storage management
echo "Longhorn: https://longhorn.fletcherlabs.net"

# Authentication setup
echo "Authentik: https://authentik.fletcherlabs.net"
```

### Emergency Procedures
```bash
# If storage issues return
kubectl -n longhorn-system logs -l app=longhorn-csi-plugin

# Check CSI drivers
kubectl get csidriver
kubectl get csinode

# Flux issues
flux reconcile kustomization apps --with-source
```

## Important Security Considerations

### ⚠️ CRITICAL: Exposed Services
1. **Prometheus is publicly accessible without authentication**
   - Contains sensitive system metrics
   - Can reveal infrastructure details
   - MUST be secured ASAP

2. **Authentik OAuth2 Apps Needed For:**
   - Prometheus (URGENT)
   - Longhorn
   - Any future admin interfaces

### SOPS Encryption
- Age key location: `~/.config/sops/age/keys.txt`
- ⚠️ This key is CRITICAL - ensure it's backed up
- All secrets properly encrypted

## Key Documentation
- Main overview: `CLUSTER-SETUP.md`
- Longhorn incident: `docs/LONGHORN-INCIDENT-POSTMORTEM-2025-06-15.md`
- OAuth2 templates: `docs/oauth2-integration-templates.md`
- Authentik setup: `docs/authentik-manual-setup-steps.md`

## Notes for Next Team
1. DO NOT change kubelet paths - K3s uses `/var/lib/rancher/k3s/agent/kubelet`
2. Monitoring fsGroup issues are worked around with local-path storage
3. All OAuth2-Proxy configurations are tested and ready to deploy
4. Backup strategy is solid - test restores regularly
5. The cluster is stable but needs auth configuration urgently

---
**Remember**: First priority is securing Prometheus. It's currently exposing all cluster metrics without any authentication!