# Storage Migration Plan: NFS to Longhorn

## Executive Summary

**Recommendation**: Migrate application configs to Longhorn, keep media data on NFS.

## Rationale

### What to Migrate to Longhorn
- **All *-config-pv volumes** (100Mi each)
  - Benefits: Atomic backups, better consistency, node failure resilience
  - Minimal storage overhead (300Mi total with 3x replication)
  - These don't actually need ReadWriteMany

### What to Keep on NFS
- **k3s-data-pv** (30Ti media storage)
  - Too large for Longhorn
  - Actually benefits from ReadWriteMany for shared access
  - Performance is fine for sequential media streaming

## Implementation Plan

### Phase 1: Create Longhorn StorageClasses
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: longhorn-nvme
parameters:
  numberOfReplicas: "3"
  staleReplicaTimeout: "2880"  # 48 hours
  diskSelector: "nvme"  # Tag your NVMe disks
  nodeSelector: "node.kubernetes.io/instance-type:nvme"
provisioner: driver.longhorn.io
allowVolumeExpansion: true
reclaimPolicy: Retain
volumeBindingMode: Immediate
```

### Phase 2: Test Migration (Bazarr as Pilot)
1. **Create new PVC**:
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: bazarr-config-longhorn
  namespace: media
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: longhorn-nvme
  resources:
    requests:
      storage: 1Gi  # Give some headroom
```

2. **Migration Steps**:
```bash
# Scale down the app
kubectl scale deployment bazarr -n media --replicas=0

# Create migration pod
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: migrate-bazarr
  namespace: media
spec:
  containers:
  - name: migrate
    image: busybox
    command: ['sh', '-c', 'sleep 3600']
    volumeMounts:
    - name: old-nfs
      mountPath: /old
    - name: new-longhorn
      mountPath: /new
  volumes:
  - name: old-nfs
    persistentVolumeClaim:
      claimName: bazarr-config-pvc
  - name: new-longhorn
    persistentVolumeClaim:
      claimName: bazarr-config-longhorn
EOF

# Copy data
kubectl exec -n media migrate-bazarr -- sh -c "cp -av /old/* /new/"

# Update deployment to use new PVC
# Then scale back up
```

### Phase 3: Rollout Strategy
1. Monitor Bazarr for 1 week
2. If stable, migrate one app per week:
   - Week 2: Prowlarr (indexer - critical)
   - Week 3: Sonarr/Radarr (automation)
   - Week 4: Jellyfin/Plex (media servers)
   - Week 5: Supporting apps

### Phase 4: Backup Configuration
```yaml
# Update Velero backup to ensure Longhorn snapshots
apiVersion: velero.io/v1
kind: Schedule
metadata:
  name: media-configs-hourly
  namespace: velero
spec:
  schedule: "0 * * * *"  # Hourly for configs
  template:
    includedNamespaces:
    - media
    storageLocation: minio-local
    volumeSnapshotLocations:
    - longhorn-csi
    ttl: "168h"  # 7 days
    includeResources:
    - persistentvolumeclaims
    - persistentvolumes
    labelSelector:
      matchLabels:
        storage-type: config  # Tag your Longhorn PVCs
```

## Risk Mitigation

1. **Keep NFS volumes** until migration is proven stable (30 days)
2. **Test restore procedure** before each app migration
3. **Monitor resource usage** - Longhorn will add ~100Mi RAM per volume
4. **Document rollback** procedure for each app

## Decision Matrix

| Aspect | Keep on NFS | Move to Longhorn |
|--------|------------|------------------|
| Backup Consistency | ❌ File-level during writes | ✅ Atomic snapshots |
| Performance | ✅ Low latency NVMe | ✅ Potentially better for SQLite |
| Complexity | ✅ Simple, proven | ❌ Distributed system |
| Resource Usage | ✅ None on K8s nodes | ❌ ~1GB RAM total overhead |
| Node Failure | ❌ Manual intervention | ✅ Automatic failover |
| Storage Efficiency | ✅ No replication | ❌ 3x storage (negligible) |

## Expected Outcomes

### Benefits
- Consistent, atomic backups of all application databases
- Automatic recovery from node failures
- Unified storage management through Kubernetes
- Better alignment with cloud-native practices

### Trade-offs
- Increased operational complexity
- ~1GB additional RAM usage across cluster
- Need to monitor Longhorn health

## Success Criteria
- Zero data loss during migration
- Backup/restore tested and working
- No performance degradation
- Applications remain stable for 30 days post-migration