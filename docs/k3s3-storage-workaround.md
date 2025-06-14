# k3s3 Longhorn CSI Driver Workaround Documentation

## Update: Longhorn CSI Driver Now Working (June 14, 2025)

### Good News!
The Longhorn CSI driver is now functioning correctly on the k3s3 node. This allows us to migrate critical workloads from local-path to replicated storage for improved data persistence and high availability.

### Migration Status
- **Monitoring Stack**: Migrated from local-path to longhorn-replicated storage
  - Prometheus: 50Gi longhorn-replicated
  - Grafana: 10Gi longhorn-replicated
  - Alertmanager: 5Gi longhorn-replicated
  - Loki: 10Gi longhorn-replicated

### Benefits of Migration
1. **Data Persistence**: 3-way replication across nodes
2. **High Availability**: Pods can be rescheduled with their data intact
3. **Node Failure Tolerance**: Monitoring data survives individual node failures
4. **Best Practices**: Proper storage for stateful workloads

---

## Historical Documentation (Preserved for Reference)

### Previous Issue Summary
The Longhorn CSI driver was failing to register on the k3s3 node, preventing pods requiring Longhorn volumes from being scheduled on this node.

### Previous Symptoms
- `kubectl get csinode k3s3` showed `drivers: null`
- Pods with Longhorn PVCs could not be scheduled on k3s3
- Error: "AttachVolume.Attach failed for volume: CSINode k3s3 does not contain driver driver.longhorn.io"

### Previous Workaround
Used local-path storage for workloads that had to run on k3s3, particularly the monitoring stack.

### Resolution
The issue appears to have been resolved, possibly due to:
- Cluster updates and reconciliations
- Longhorn controller improvements
- Node configuration stabilization

## Current Best Practices

### Storage Class Selection
1. **longhorn-replicated**: Use for critical stateful workloads requiring data persistence
2. **longhorn-nvme**: Use for performance-sensitive workloads with persistence needs
3. **local-path**: Reserve for temporary data or extreme performance requirements

### Monitoring
Regular checks to ensure Longhorn remains healthy:
```bash
# Check Longhorn CSI driver on k3s3
kubectl get csinode k3s3 -o yaml | grep driver.longhorn.io

# Monitor storage health
kubectl get pv | grep longhorn

# Check Longhorn system status
kubectl get pods -n longhorn-system
```

## Migration Notes
When migrating from local-path to Longhorn:
1. Existing PVCs must be deleted and recreated
2. Data on local-path volumes will be lost
3. Plan migrations during maintenance windows
4. Back up critical data before migration

---
*Original Decision Date: June 13, 2025*
*Updated: June 14, 2025 - Longhorn now working, monitoring stack migrated*
*Review Date: Quarterly or if issues resurface*