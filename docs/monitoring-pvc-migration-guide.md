# Monitoring Stack PVC Migration Guide

## Critical: Manual Intervention Required

The monitoring stack has been configured to use `longhorn-replicated` storage, but the PVCs cannot be automatically migrated because Kubernetes PVCs have immutable storage classes.

## Current State
- Configuration updated to use `longhorn-replicated`
- Existing PVCs still using `local-path`
- HelmReleases failing due to immutable PVC spec

## Migration Steps

### 1. Backup Important Dashboards (Optional)
```bash
# Export Grafana dashboards if needed
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
# Access http://localhost:3000 and export dashboards
```

### 2. Scale Down Monitoring Workloads
```bash
# Scale down all monitoring components to release PVCs
kubectl scale -n monitoring deployment kube-prometheus-stack-grafana --replicas=0
kubectl scale -n monitoring deployment kube-prometheus-stack-operator --replicas=0
kubectl scale -n monitoring statefulset prometheus-kube-prometheus-stack-prometheus --replicas=0
kubectl scale -n monitoring statefulset loki --replicas=0
kubectl scale -n monitoring statefulset alertmanager-kube-prometheus-stack-alertmanager --replicas=0

# Verify all pods are terminated
kubectl get pods -n monitoring
```

### 3. Delete Existing PVCs
```bash
# Delete all monitoring PVCs
kubectl delete pvc -n monitoring --all

# Verify deletion
kubectl get pvc -n monitoring
```

### 4. Trigger Flux Reconciliation
```bash
# Force reconciliation to create new PVCs with longhorn-replicated
flux reconcile helmrelease -n monitoring kube-prometheus-stack
flux reconcile helmrelease -n monitoring loki
flux reconcile helmrelease -n monitoring dcgm-exporter

# Monitor PVC creation
kubectl get pvc -n monitoring -w
```

### 5. Verify New Storage Class
```bash
# Confirm new PVCs are using longhorn-replicated
kubectl get pvc -n monitoring -o custom-columns=NAME:.metadata.name,STORAGECLASS:.spec.storageClassName
```

### 6. Check Pod Status
```bash
# Monitor pods coming back online
kubectl get pods -n monitoring -w

# Check for any issues
kubectl describe pods -n monitoring | grep -A5 "Warning\|Error"
```

## Expected Outcome
- All monitoring components running on longhorn-replicated storage
- 3-way replication for data durability
- Data persists through node failures

## Data Loss Notice
⚠️ **Warning**: This migration will result in loss of:
- Historical Prometheus metrics
- Grafana dashboard configurations (if not backed up)
- Loki log history
- Alertmanager silence history

This is a one-time data loss accepted for long-term persistence benefits.

## Rollback Plan
If issues occur:
1. Scale down workloads again
2. Delete new PVCs
3. Revert HelmRelease changes in Git
4. Force Flux reconciliation

---
*Created: June 14, 2025*
*Part of 48-hour autonomous operation fixes*