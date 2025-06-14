# Tasks for Next AI Session

## Context
This document was created on 2025-06-13 after completing Week 3 observability implementation. Following the resolution of networking issues on k3s1 and successful backup integration, this document has been updated to reflect current priorities.

**Last Updated**: 2025-06-14 - Updated to reflect resolved cluster state. Removed obsolete CSI troubleshooting section.

## Immediate Tasks After System Restart

### 1. Complete Remaining Flux Reconciliations
**Objective:** Fix the two remaining Flux issues to ensure full GitOps control.

**Actionable Checklist:**
- [ ] **Fix Authentik Secret Issue**
  - Error: `could not resolve Secret chart values reference 'authentik/authentik-secret'`
  - Check if secret exists: `kubectl get secret -n authentik authentik-secret`
  - If missing, create from template or documentation
  - Force reconciliation: `flux reconcile hr authentik -n authentik`

- [ ] **Install Intel GPU Plugin CRDs**
  - Error: `no matches for kind "GpuDevicePlugin" in version "deviceplugin.intel.com/v1"`
  - This requires the Intel device plugin CRDs to be installed
  - Check if this is needed (only if using Intel GPUs)
  - If not needed, consider removing the HelmRelease

### 2. Implement WSL2 GPU Node (After NIC Replacement)
- **Goal**: Add RTX 4090 to cluster via dedicated WSL2 instance
- **Plan**: See `docs/wsl2-gpu-node-plan.md` for detailed steps
- **Script**: Use `docs/setup-wsl-k3s-node.ps1` from Windows PowerShell

### 3. Configure Offsite Backups
**Objective:** Complete Backblaze B2 integration for offsite disaster recovery.

**Actionable Checklist:**
- [ ] **Step 1: Verify Backblaze B2 Bucket**
  - Bucket already created with encryption enabled
  - Review configuration in `/home/josh/flux-k3s/docs/backblaze-b2-setup.md`

- [ ] **Step 2: Configure Velero B2 Integration**
  - Follow steps in `/home/josh/flux-k3s/docs/velero-offsite-setup.md`
  - Key commands:
    ```bash
    # Create B2 credentials secret
    kubectl create secret generic b2-credentials \
      -n velero \
      --from-literal=cloud=<base64-encoded-credentials>
    
    # Create backup location
    velero backup-location create b2-offsite \
      --provider aws \
      --bucket <YOUR_B2_BUCKET> \
      --config region=us-west-004,s3ForcePathStyle="true",s3Url=https://s3.us-west-004.backblazeb2.com
    ```

- [ ] **Step 3: Test Offsite Backup**
  - Create test backup: `velero backup create test-b2-backup --include-namespaces default`
  - Verify completion: `velero backup describe test-b2-backup`
  - Check B2 bucket for backup files

- [ ] **Step 4: Configure Backup Schedule**
  - Create daily backup schedule for critical namespaces
  - Implement retention policy (30 days suggested)

### 4. Migrate Monitoring to Longhorn Storage
- **Status**: Now possible since Longhorn is fully operational
- **Files**: Update helm-release.yaml files in monitoring stack
- **Change**: Switch from local-path to longhorn storage classes
- **Priority**: Medium - system is stable but using ephemeral storage

## Current Cluster State

### Working Services
- All media apps (Jellyfin, Plex, *arr stack)
- AI stack (Ollama, Open WebUI, Automatic1111)
- Authentication (Authentik - but 2FA not enabled)
- Storage (Longhorn - except on k3s3)
- Backups (Velero with local MinIO)
- Monitoring (Prometheus, Grafana, Loki)

### Known Issues
1. Monitoring using local-path storage (should migrate to Longhorn)
2. Authentik secret configuration missing
3. Intel GPU plugin CRDs not installed
4. ~~CSI driver issues~~ ✅ FIXED - Was actually k3s1 networking issue
5. ~~No offsite backups~~ ✅ FIXED - B2 integration complete
6. ~~No TLS/HTTPS~~ ✅ FIXED - HTTPS enabled with Let's Encrypt

### Access Points
- Grafana: http://grafana.fletcherlabs.net
- All services: http://<service>.fletcherlabs.net
- SSH: Direct to any node (k3s1, k3s2, k3s3, k3s-master1)

## Important Notes
- SOPS age key at `~/.config/sops/age/keys.txt` - **⚠️ CRITICAL: Ensure this is backed up!**
- Do NOT enable Authentik 2FA until all infrastructure work complete
- Tesla T4 is in k3s3, RTX 4090 is in desktop (not yet in cluster)
- VM snapshots available for emergency rollback
- See `/home/josh/flux-k3s/EMERGENCY-DOWNGRADE-COMMANDS.md` for K3s version rollback procedures

## Current Priorities

### Immediate Tasks:
1. **Fix Remaining Flux Issues**
   - Authentik secret configuration
   - Intel GPU plugin CRDs (or remove if not needed)

2. **Migrate Monitoring Stack**
   - Move from local-path to Longhorn storage
   - Ensure data persistence for Prometheus/Grafana

3. **Documentation Updates**
   - Add incident post-mortem for k3s1 networking issue
   - Update troubleshooting guides with lessons learned

### Future Considerations:
1. **Add WSL2 GPU Node** (after NIC replacement)
2. **Improve Node Health Monitoring**
3. **Consider Storage Redundancy**

## Related Documentation
- CSI Troubleshooting: `/home/josh/flux-k3s/docs/csi-troubleshooting-guide.md`
- Storage Migration Plan: `/home/josh/flux-k3s/docs/storage-migration-plan.md`
- Cluster Overview: `/home/josh/flux-k3s/CLUSTER-SETUP.md`