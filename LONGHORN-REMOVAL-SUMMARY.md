# Longhorn Removal Summary - June 16, 2025

## Changes Made

### 1. Storage Class Updates
- **Prometheus Storage**: Changed from `longhorn-nvme` to `local-path` in:
  - `/clusters/k3s-home/apps/monitoring/kube-prometheus-stack/helm-release.yaml`
  - Prometheus volume: 50Gi
  - Grafana volume: 10Gi  
  - Alertmanager volume: 5Gi

- **Loki Storage**: Changed from `longhorn-nvme` to `local-path` in:
  - `/clusters/k3s-home/apps/monitoring/loki/helm-release.yaml`
  - Loki volume: 10Gi

- **Media PVCs**: Updated all media service PVCs in:
  - `/manifests/media-pvcs.yaml`
  - Affected services: Jellyfin, Sonarr, Radarr, Lidarr, Prowlarr, Bazarr, Overseerr, Sabnzbd, Whisparr

- **Bazarr Migration PVC**: Updated in:
  - `/clusters/k3s-home/apps/media/bazarr/migration/01-longhorn-pvc.yaml`

### 2. Alert Rules
- Disabled Longhorn alerts in:
  - `/clusters/k3s-home/apps/monitoring/kube-prometheus-stack/alerts/kustomization.yaml`
  - Commented out `longhorn-alerts.yaml` resource

### 3. Velero Backup Configuration
- **Volume Snapshot Location**: Changed from `longhorn-csi` to `local-path-csi` in:
  - `/clusters/k3s-home/apps/velero/overlays/production/locations/volume-snapshot-locations.yaml`
  - Note: local-path doesn't support snapshots (placeholder only)

- **Backup Schedules**: Updated in:
  - `/clusters/k3s-home/apps/velero/overlays/production/schedules/offsite-backup-schedule.yaml`
  - `/clusters/k3s-home/apps/velero/overlays/production/schedules/local-backup-schedule.yaml`
  - Removed `longhorn-system` namespace from backups
  - Added `monitoring` namespace to critical backups
  - Disabled volume snapshots (not supported by local-path)

### 4. Kustomization Cleanup
- **Deleted Flux Kustomizations**:
  - `kubectl delete kustomization longhorn -n flux-system`
  - `kubectl delete kustomization longhorn-system -n flux-system`

- **Removed Dependencies**:
  - Patched monitoring kustomization to remove longhorn dependency
  - Disabled longhorn HelmRepository in sources

### 5. HelmRepository Sources
- Commented out longhorn-helmrepository.yaml in:
  - `/clusters/k3s-home/apps/sources/kustomization.yaml`

## Impact Assessment

### Storage Implications
- All persistent storage now uses `local-path` provisioner
- No distributed storage redundancy
- Data stored locally on nodes where pods are scheduled
- No volume snapshots available

### Backup Considerations
- Velero backups will only backup Kubernetes objects
- Volume data backup requires separate solution
- Consider NFS or external backup for media data

### Performance
- Improved: No fsGroup mounting issues
- Improved: Direct local disk access
- Reduced: No storage replication overhead
- Risk: Data loss if node disk fails

## Next Steps for Future Team

1. **Monitor Storage Usage**
   ```bash
   kubectl get pv
   kubectl get pvc -A
   ```

2. **Consider NFS for Media**
   - Media libraries could use NFS mounts
   - Better for shared access across nodes

3. **Backup Strategy**
   - Implement regular backups of local-path volumes
   - Consider external backup solution for critical data

4. **Future Storage Options**
   - Rook-Ceph (if distributed storage needed again)
   - OpenEBS (alternative to Longhorn)
   - NFS CSI driver for network storage

## Verification Commands

```bash
# Check for remaining longhorn references
grep -r "longhorn" /home/josh/flux-k3s/clusters/k3s-home/ --include="*.yaml" | grep -v ".disabled"

# Verify PVC storage classes
kubectl get pvc -A -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,STORAGECLASS:.spec.storageClassName | grep -v local-path

# Check kustomization status
kubectl get kustomizations -n flux-system | grep -E "(False|Unknown)"
```

All Longhorn dependencies have been successfully removed from the active cluster configuration.