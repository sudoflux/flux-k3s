# Next Session Prompt - K3s Homelab Cluster

## Session Context
**Date**: June 16, 2025  
**Status**: Foundation Complete - Critical SPOFs Remain  
**Last Session**: Fixed Intel GPU, cleaned cluster, identified Longhorn fsGroup bug  
**Comprehensive Analysis**: See [DEPLOYMENT-ANALYSIS.md](DEPLOYMENT-ANALYSIS.md)

## 🎉 Recent Accomplishments
- ✅ Prometheus secured with OAuth2-Proxy + Authentik
- ✅ Longhorn secured with OAuth2-Proxy + Authentik  
- ✅ Created automated OAuth2 deployment script
- ✅ DCGM exporter fixed and collecting GPU metrics
- ✅ Intel GPU plugin working on BOTH k3s1 and k3s2
- ✅ All media services recovered and running
- ✅ Cluster thoroughly cleaned of orphaned resources
- ✅ Week 1-3 of deployment plan COMPLETE

## 🔴 Critical Issues (SPOFs)

### 1. Storage Single Point of Failure
```
Current: Dell R730 hosts ALL NFS storage
Risk: Hardware failure = total media data loss (30TB)
Priority: CATASTROPHIC
```

### 2. No Control Plane HA
```
Current: Single k3s-master1 VM
Risk: VM failure = no cluster management
Priority: CRITICAL
```

### 3. Longhorn fsGroup Bug
```
Current: v1.6.2 has known bug preventing monitoring stack from using Longhorn
Impact: Prometheus/AlertManager/Grafana on local-path instead of Longhorn
Fix: Upgrade to Longhorn 1.9.x
Priority: HIGH
```

## 🎯 Immediate Actions (This Session)

### 1. Upgrade Longhorn to v1.9.x
```bash
# Current version with fsGroup bug
kubectl get helmrelease -n longhorn-system longhorn -o jsonpath='{.spec.chart.spec.version}'
# Shows: 1.6.2

# Update HelmRelease to 1.9.x
# See: docs/longhorn-fsgroup-issue.md for full details

# The bug prevents pods with fsGroup from mounting Longhorn volumes
# This is why monitoring stack is on local-path
```

### 2. Fix Grafana After Upgrade
```bash
# Grafana is currently scaled to 0 due to fsGroup mount failures
kubectl scale deployment -n monitoring kube-prometheus-stack-grafana --replicas=1

# After Longhorn upgrade, it should start successfully
# Then import NVIDIA GPU dashboard: ID 12239
```

### 3. Test Velero Restore
```bash
# Create test backup
velero backup create test-$(date +%Y%m%d-%H%M%S) --include-namespaces default

# List backups
velero backup get

# Create test restore (to different namespace)
velero restore create test-restore --from-backup <backup-name> --namespace-mappings default:restore-test
```

### 4. Fix SOPS in Monitoring Namespace
```bash
# Check kustomize-controller logs
kubectl logs -n flux-system deployment/kustomize-controller | grep -i "monitoring\|sops"

# Verify SOPS configuration
kubectl get secret -n flux-system sops-age -o yaml
```

## 📋 Today's Priority Order

1. **Longhorn Upgrade** (2-3 hours)
   - Backup data first!
   - Upgrade from 1.6.2 to 1.9.x
   - Test with a pod that uses fsGroup
   - Move monitoring stack to Longhorn

2. **Fix Grafana** (30 min)
   - Scale back to 1 replica
   - Verify Longhorn PVC mounts correctly
   - Import GPU dashboards

3. **Backup Testing** (45 min)
   - Test full restore procedure
   - Document recovery time
   - Update runbook

4. **SOPS Fix** (30 min)
   - Debug monitoring namespace
   - Encrypt OAuth2 secrets
   - Remove plain text secrets

5. **Documentation** (30 min)
   - Update cluster status
   - Document Longhorn upgrade
   - Create GPU monitoring guide

## 🏗️ Architecture Decisions Needed

### Storage Redundancy Options
1. **GlusterFS** - Distributed NFS replacement
2. **SeaweedFS** - S3-compatible distributed storage  
3. **Longhorn on all nodes** - Simpler but less efficient
4. **Secondary NFS + rsync** - Quick win but not ideal

### HA Control Plane Approach
1. **3x VMs with embedded etcd** - K3s native HA
2. **External etcd cluster** - More complex, more reliable
3. **k3sup** for easy multi-master setup

## 📊 Quick Status Check

```bash
# Cluster health
kubectl get nodes
kubectl top nodes

# Storage status  
kubectl get pv,pvc -A | grep -v "Bound"
kubectl get storageclass

# Pod issues
kubectl get pods -A | grep -v "Running\|Completed"

# Flux status
flux get all -A | grep -v "True"

# Backup status
velero backup get
velero schedule get

# GPU resources
kubectl get nodes -o custom-columns=NAME:.metadata.name,INTEL:.status.allocatable."gpu\.intel\.com/i915",NVIDIA:.status.allocatable."nvidia\.com/gpu"
```

## 🔧 Useful Commands

```bash
# Force reconcile everything
flux reconcile source git flux-system
flux reconcile kustomization --all

# Check OAuth2 proxy status
kubectl get pods -A -l app.kubernetes.io/name=oauth2-proxy

# View recent events
kubectl get events -A --sort-by='.lastTimestamp' | tail -20

# Check certificate status
kubectl get certificate -A
```

## 📚 Key Documentation
- **Comprehensive Analysis**: [DEPLOYMENT-ANALYSIS.md](DEPLOYMENT-ANALYSIS.md)
- **Cluster Overview**: [CLUSTER-SETUP.md](CLUSTER-SETUP.md)
- **Longhorn fsGroup Bug**: [docs/longhorn-fsgroup-issue.md](docs/longhorn-fsgroup-issue.md)
- **OAuth2 Automation**: `scripts/deploy-oauth2-service.sh`
- **Intel GPU K3s Issue**: [docs/intel-gpu-plugin-k3s-issue.md](docs/intel-gpu-plugin-k3s-issue.md)

## 🎓 Key Technical Debt

1. **Legacy kubelet directories** - Created during Longhorn incident, now required for GPU support
2. **Monitoring on local-path** - Due to Longhorn fsGroup bug, needs v1.9.x upgrade
3. **No HA** - Single points of failure for storage and control plane

---
**Remember**: Longhorn upgrade is priority #1 to get monitoring fully on distributed storage!