# Evening Shift Summary - June 16, 2025

## Shift Overview
**Duration**: 20:00 - 20:15 UTC  
**Focus**: Investigating Longhorn fsGroup issue preventing monitoring stack from using distributed storage  
**Result**: Root cause identified as Longhorn v1.6.2 bug - upgrade required but deemed too risky

## Key Accomplishments

### 1. Root Cause Analysis ✅
- Identified the fsGroup issue as a **race condition** in Longhorn v1.6.2
- CSI driver fails to create mount point before kubelet tries to apply fsGroup permissions
- Confirmed pods without fsGroup mount successfully, proving it's specifically an fsGroup bug

### 2. Comprehensive Testing ✅
- Created test pods with and without fsGroup to isolate the issue
- Verified `/var/lib/kubelet` directories are hard-linked to K3s paths (same inodes)
- Confirmed CSI driver reports success but doesn't actually create mounts with fsGroup

### 3. Evaluated All Workarounds ✅
- **K3s Configuration**: Not viable - directories already linked
- **Symlinks**: Already in place via hard links
- **Bind Mounts**: Would hide existing content, doesn't solve race condition
- **Conclusion**: No workaround possible for this bug

### 4. Upgrade Path Documented ✅
- Confirmed mandatory staged upgrade: v1.6.2 → v1.7.x → v1.8.x → v1.9.0
- Each upgrade stage requires validation before proceeding
- Total estimated time: 2-4 hours with high risk

## Critical Findings

### The fsGroup Bug Details
```
Error: applyFSGroup failed for vol pvc-xxx: lstat /var/lib/kubelet/pods/.../mount: no such file or directory
```
- Occurs ONLY when pods specify fsGroup/runAsUser
- CSI driver should create `mount` subdirectory but timing issue prevents it
- Affects Grafana, Prometheus, AlertManager, and other security-conscious apps

### Why Upgrade is Risky
1. **No Staging Environment** - Cannot test the 3-stage upgrade process
2. **Critical Data at Risk** - All application configs stored in Longhorn
3. **No Easy Rollback** - Once CRDs are upgraded, reverting is complex
4. **Cascading Failures** - If upgrade fails, could lose access to all Longhorn volumes

## Recommendations

### Immediate (This Week)
1. **Keep Status Quo** - Monitoring stack remains on local-path storage
2. **Document Workaround** - Apps requiring fsGroup must use local-path
3. **Monitor Longhorn Health** - Ensure no other issues develop

### Short Term (Next Month)
1. **Build Staging Environment** - Critical before attempting upgrade
2. **Test Upgrade Path** - Practice the 3-stage upgrade in staging
3. **Create Backup Strategy** - Ensure all Longhorn data is backed up

### Long Term
1. **Schedule Maintenance Window** - 4-6 hours for production upgrade
2. **Consider Alternatives** - Evaluate if Longhorn is the right choice
3. **Implement HA Storage** - Current NFS SPOF is higher priority

## Current Cluster State
- **All Services**: Running normally
- **Monitoring Stack**: Functional on local-path storage
- **Longhorn**: v1.6.2 working for non-fsGroup workloads
- **Risk Level**: Acceptable - fsGroup limitation documented

## Hand-off Notes
The fsGroup issue has been thoroughly investigated. The root cause is a confirmed bug in Longhorn v1.6.2 that requires a complex multi-stage upgrade to resolve. Given the high risk without a staging environment, the recommendation is to postpone the upgrade and focus on higher priority issues like the storage SPOF and control plane HA.

All investigation results have been documented in:
- `/docs/longhorn-fsgroup-investigation-results.md`
- `/docs/longhorn-fsgroup-fix-attempt.md`
- `/docs/longhorn-fsgroup-k3s-issue.md`

## Next Priority Actions
1. Address storage SPOF (Dell R730 hosting all NFS)
2. Implement control plane HA (3 master nodes)
3. Create staging environment for testing upgrades