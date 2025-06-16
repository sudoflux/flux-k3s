# Next Session Prompt - K3s Homelab Cluster

## Session Context
**Date**: June 16, 2025  
**Status**: Foundation Complete - Critical SPOFs Remain  
**Last Session**: Secured Prometheus & Longhorn with OAuth2  
**Comprehensive Analysis**: See [DEPLOYMENT-ANALYSIS.md](DEPLOYMENT-ANALYSIS.md)

## 🎉 Recent Accomplishments
- ✅ Prometheus secured with OAuth2-Proxy + Authentik
- ✅ Longhorn secured with OAuth2-Proxy + Authentik  
- ✅ Created automated OAuth2 deployment script
- ✅ DCGM exporter fixed and collecting GPU metrics
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

### 3. GPU Monitoring Broken
```
Current: DCGM exporter in CrashLoopBackOff
Risk: No visibility into GPU time-slicing
Priority: HIGH
```

## 🎯 Immediate Actions (This Session)

### 1. Fix DCGM Exporter
```bash
# Debug the GPU monitoring
kubectl logs -n monitoring $(kubectl get pods -n monitoring -l app.kubernetes.io/name=dcgm-exporter -o jsonpath='{.items[0].metadata.name}')
kubectl describe pod -n monitoring -l app.kubernetes.io/name=dcgm-exporter

# Check if GPU is visible
kubectl exec -it -n monitoring $(kubectl get pods -n monitoring -l app.kubernetes.io/name=dcgm-exporter -o jsonpath='{.items[0].metadata.name}') -- nvidia-smi
```

### 2. Test Velero Restore
```bash
# Create test backup
velero backup create test-$(date +%Y%m%d-%H%M%S) --include-namespaces default

# List backups
velero backup get

# Create test restore (to different namespace)
velero restore create test-restore --from-backup <backup-name> --namespace-mappings default:restore-test
```

### 3. Fix SOPS in Monitoring Namespace
```bash
# Check kustomize-controller logs
kubectl logs -n flux-system deployment/kustomize-controller | grep -i "monitoring\|sops"

# Verify SOPS configuration
kubectl get secret -n flux-system sops-age -o yaml
```

## 📋 Today's Priority Order

1. **DCGM Exporter** (30 min)
   - Fix GPU metrics collection
   - Verify Grafana dashboard

2. **Backup Testing** (45 min)
   - Test full restore procedure
   - Document recovery time
   - Update runbook

3. **SOPS Fix** (30 min)
   - Debug monitoring namespace
   - Encrypt OAuth2 secrets
   - Remove plain text secrets

4. **Documentation** (30 min)
   - Archive old critical alerts
   - Update cluster status
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
- **OAuth2 Automation**: `scripts/deploy-oauth2-service.sh`
- **Longhorn Incident**: [docs/LONGHORN-INCIDENT-POSTMORTEM-2025-06-15.md](docs/LONGHORN-INCIDENT-POSTMORTEM-2025-06-15.md)

## 🎓 Learning from Incidents
1. **Always test changes** in non-production first
2. **Never modify critical paths** without migration plan
3. **Monitor CSI driver health** continuously
4. **Document everything** - saved hours during recovery

---
**Remember**: Foundation is solid, but those SPOFs need urgent attention!