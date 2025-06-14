# Bazarr NFS to Longhorn Migration Steps

## Pre-Migration Checklist
- [ ] Bazarr is currently running and healthy
- [ ] Recent backup exists (check Velero)
- [ ] No active downloads/subtitle searches in progress
- [ ] Note current Bazarr version for consistency

## Migration Process

### Step 1: Create Longhorn PVC
```bash
kubectl apply -f 01-longhorn-pvc.yaml

# Verify PVC is bound
kubectl get pvc bazarr-config-longhorn -n media
```

### Step 2: Scale Down Bazarr
```bash
# Record current state
kubectl get deployment bazarr -n media -o yaml > bazarr-current-state.yaml

# Scale down
kubectl scale deployment bazarr -n media --replicas=0

# Verify it's stopped
kubectl get pods -n media | grep bazarr
```

### Step 3: Run Migration Job
```bash
# Start the migration
kubectl apply -f 02-migration-job.yaml

# Watch the logs
kubectl logs -n media -f job/bazarr-migrate-to-longhorn

# Wait for completion
kubectl wait --for=condition=complete --timeout=300s job/bazarr-migrate-to-longhorn -n media
```

### Step 4: Update Bazarr Deployment
```bash
# Edit the deployment to use new PVC
kubectl edit deployment bazarr -n media

# Change:
#   claimName: bazarr-config-pvc
# To:
#   claimName: bazarr-config-longhorn
```

### Step 5: Scale Up and Verify
```bash
# Scale back up
kubectl scale deployment bazarr -n media --replicas=1

# Watch pod startup
kubectl logs -n media -f deployment/bazarr

# Check pod is running
kubectl get pods -n media | grep bazarr
```

### Step 6: Application Verification
1. Access Bazarr web UI at http://bazarr.fletcherlabs.net
2. Check settings are preserved
3. Verify subtitle providers are connected
4. Test a subtitle search
5. Check logs for any errors

### Step 7: Create Backup
```bash
# Create immediate backup of new Longhorn volume
kubectl apply -f - <<EOF
apiVersion: velero.io/v1
kind: Backup
metadata:
  name: bazarr-post-migration-$(date +%Y%m%d%H%M%S)
  namespace: velero
spec:
  includedNamespaces:
  - media
  includedResources:
  - persistentvolumeclaims
  - persistentvolumes
  labelSelector:
    matchLabels:
      app: bazarr
  storageLocation: minio-local
  volumeSnapshotLocations:
  - longhorn-csi
EOF
```

## Rollback Procedure (if needed)

### Quick Rollback (within minutes)
```bash
# Scale down
kubectl scale deployment bazarr -n media --replicas=0

# Edit deployment back to original PVC
kubectl edit deployment bazarr -n media
# Change claimName back to: bazarr-config-pvc

# Scale up
kubectl scale deployment bazarr -n media --replicas=1
```

### Clean Rollback (if data corrupted)
```bash
# Use the backup deployment
kubectl apply -f 03-backup-deployment.yaml
```

## Post-Migration Monitoring (7 days)

### Daily Checks:
- [ ] Day 1: Application starts correctly
- [ ] Day 2: Subtitle searches working
- [ ] Day 3: No database corruption
- [ ] Day 4: Performance acceptable
- [ ] Day 5: Backups completing
- [ ] Day 6: No unexpected errors
- [ ] Day 7: Ready for next app

### Metrics to Monitor:
- Pod restart count
- Longhorn volume metrics
- Application response time
- Log errors

## Success Criteria
- Zero data loss
- All settings preserved
- Performance equal or better
- Successful backup/restore test
- 7 days stable operation

## Cleanup (after 30 days)
```bash
# Delete migration job
kubectl delete job bazarr-migrate-to-longhorn -n media

# Remove old NFS PVC binding (keep PV for safety)
kubectl delete pvc bazarr-config-pvc -n media
```

## Notes
- Keep NFS data for 30 days as safety net
- Document any issues for next migration
- Update runbook with lessons learned