# k3s3 Longhorn CSI Driver Workaround Documentation

## Issue Summary
The Longhorn CSI driver fails to register on the k3s3 node, preventing pods requiring Longhorn volumes from being scheduled on this node.

## Symptoms
- `kubectl get csinode k3s3` shows `drivers: null`
- Pods with Longhorn PVCs cannot be scheduled on k3s3
- Error: "AttachVolume.Attach failed for volume: CSINode k3s3 does not contain driver driver.longhorn.io"

## Root Cause Analysis
After extensive troubleshooting, the exact root cause remains unclear. Potential factors:
- Node-specific configuration differences
- Network connectivity issues between k3s3 and Longhorn components
- Timing issues during node initialization
- Possible kernel module or system-level incompatibilities

## Decision: Use Local-Path Storage

### Rationale
1. **Time Investment**: Further debugging has diminishing returns
2. **Impact Scope**: Only affects specific workloads on k3s3
3. **Viable Alternative**: local-path storage meets requirements
4. **Production Stability**: Avoiding complex fixes reduces risk

### Implementation
For workloads that must run on k3s3 but need persistent storage:
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: example-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
  storageClassName: local-path  # Instead of longhorn
```

## Affected Workloads

### Current Impact
- **Alertmanager**: Using local-path storage
- **Loki**: Using local-path storage
- **Monitoring Stack**: Configured to use local-path where needed

### Mitigation
These workloads are stateful but not critical for data persistence:
- Alertmanager state can be rebuilt from Prometheus
- Loki logs are time-bound and rotate naturally
- Monitoring data is valuable but not business-critical

## Future Considerations

### If Longhorn on k3s3 Becomes Critical
1. **Fresh Node Rebuild**: Complete node reinstallation might resolve
2. **Alternative CSI**: Consider OpenEBS or Rook-Ceph
3. **Direct Troubleshooting**: Engage Longhorn community support

### Current Strategy
- Use k3s3 primarily for GPU workloads
- Use k3s1/k3s2 for storage-intensive workloads
- Leverage node affinity to control placement

## Monitoring
Regular checks to ensure workaround remains viable:
```bash
# Check storage usage on k3s3
kubectl get pv | grep local-path | grep k3s3

# Monitor pod placement
kubectl get pods -A -o wide | grep k3s3
```

## Conclusion
This pragmatic approach prioritizes cluster stability and feature delivery over perfect storage uniformity. The workaround is well-documented, reversible, and doesn't impact core functionality.

---
*Decision Date: June 13, 2025*
*Review Date: Quarterly or if requirements change*