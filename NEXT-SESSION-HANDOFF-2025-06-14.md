# Next Session Handoff Documentation
## Critical Issue: Longhorn CSI Driver K3s Compatibility
### Date: June 14, 2025

## 🚨 CRITICAL BLOCKER: Longhorn CSI Not Working with K3s

### Issue Summary
Longhorn CSI driver cannot mount volumes on K3s due to kubelet path mismatch. This blocks ALL persistent volume operations for Longhorn storage.

**Error Message:**
```
MountVolume.SetUp failed for volume "pvc-xxx" : applyFSGroup failed for vol pvc-xxx: 
lstat /var/lib/kubelet/pods/xxx/volumes/kubernetes.io~csi/pvc-xxx/mount: no such file or directory
```

### Root Cause
K3s uses non-standard paths:
- **K3s kubelet root**: `/var/lib/rancher/k3s/agent/kubelet/`
- **Standard Kubernetes**: `/var/lib/kubelet/`

The CSI driver is registered correctly, volumes attach successfully, but the final mount operation fails because kubelet and the CSI plugin disagree on paths.

## What We Tried (All Failed)

### 1. ✅ Feature Gate Disable (ALREADY APPLIED)
```yaml
# /etc/rancher/k3s/config.yaml on k3s-master1
kube-apiserver-arg:
  - "feature-gates=AuthorizeNodeWithSelectors=false"
```

### 2. ✅ Helm Values Configuration (ALREADY SET)
```yaml
# In Longhorn HelmRelease
csi:
  kubeletRootDir: /var/lib/rancher/k3s/agent/kubelet
```

### 3. ✅ Environment Variables Added to CSI Plugin
```bash
kubectl patch daemonset longhorn-csi-plugin -n longhorn-system --type='json' -p='[
  {"op": "add", "path": "/spec/template/spec/containers/0/env/-", "value": {"name": "KUBELET_ROOT_DIR", "value": "/var/lib/rancher/k3s/agent/kubelet"}},
  {"op": "add", "path": "/spec/template/spec/containers/1/env/-", "value": {"name": "KUBELET_ROOT_DIR", "value": "/var/lib/rancher/k3s/agent/kubelet"}},
  {"op": "add", "path": "/spec/template/spec/containers/2/env/-", "value": {"name": "KUBELET_ROOT_DIR", "value": "/var/lib/rancher/k3s/agent/kubelet"}}
]'
```

### 4. ✅ Bind Mounts with rshared Propagation (CURRENTLY ACTIVE)
```bash
# On all nodes (k3s1, k3s2, k3s3)
sudo mount --bind --make-rshared /var/lib/rancher/k3s/agent/kubelet/pods /var/lib/kubelet/pods
sudo mount --bind --make-rshared /var/lib/rancher/k3s/agent/kubelet/plugins /var/lib/kubelet/plugins
sudo mount --bind --make-rshared /var/lib/rancher/k3s/agent/kubelet/plugins_registry /var/lib/kubelet/plugins_registry

# Added to /etc/fstab for persistence:
/var/lib/rancher/k3s/agent/kubelet/plugins /var/lib/kubelet/plugins none bind 0 0
/var/lib/rancher/k3s/agent/kubelet/pods /var/lib/kubelet/pods none bind 0 0
/var/lib/rancher/k3s/agent/kubelet/plugins_registry /var/lib/kubelet/plugins_registry none bind 0 0
```

### 5. ❌ Result: CSI Operations Still Fail
- CSI driver IS registered: `kubectl get csidriver` shows driver.longhorn.io
- Volumes DO attach: `kubectl get volumeattachment` shows attached volumes
- Mount FAILS: kubelet cannot find the mount path

## Current State

### What's Working
- ✅ Local-path storage (emergency fallback)
- ✅ Authentik SSO fully configured
- ✅ GPU resource management implemented
- ✅ All nodes healthy and running

### What's Broken
- ❌ ALL Longhorn volume mounts fail
- ❌ Monitoring pods stuck in ContainerCreating
- ❌ Cannot use Longhorn for ANY workload

### Affected Pods
```bash
# All stuck in Init or ContainerCreating:
monitoring/loki-0
monitoring/alertmanager-kube-prometheus-stack-alertmanager-0
monitoring/prometheus-kube-prometheus-stack-prometheus-0
monitoring/kube-prometheus-stack-grafana-*
```

## Debugging Commands

### Check CSI Registration
```bash
# Verify CSI driver is registered
kubectl get csidriver

# Check CSI pods are running
kubectl get pods -n longhorn-system -l app=longhorn-csi-plugin

# View CSI plugin logs
kubectl logs -n longhorn-system -l app=longhorn-csi-plugin -c longhorn-csi-plugin
```

### Check Mount Issues
```bash
# On affected node (usually k3s3)
sudo ls -la /var/lib/rancher/k3s/agent/kubelet/pods/
sudo ls -la /var/lib/kubelet/pods/

# Check bind mounts
mount | grep kubelet

# Check CSI socket
sudo ls -la /var/lib/rancher/k3s/agent/kubelet/plugins_registry/
```

### Monitor Pod Events
```bash
# Watch for mount errors
kubectl describe pod loki-0 -n monitoring | grep -A 20 Events:
```

## Potential Solutions (Not Yet Tried)

### Option 1: Patch Longhorn CSI Plugin Code
The CSI plugin may be hardcoded to use `/var/lib/kubelet`. Need to check Longhorn source code for:
- NodePublishVolume implementation
- Mount path construction logic
- Possible configuration options we missed

### Option 2: Custom K3s Configuration
Research if K3s has additional kubelet args to change its root directory to standard path:
```bash
# Theoretical - needs verification
--kubelet-arg="--root-dir=/var/lib/kubelet"
```

### Option 3: Alternative CSI Drivers
Consider replacing Longhorn with K3s-compatible alternatives:
- **Rook/Ceph**: More complex but K8s native
- **OpenEBS**: Claims K3s compatibility
- **Rancher Local Path**: Already working but not distributed

### Option 4: Systemd Mount Units
Create proper systemd mount units instead of bind mounts to ensure proper ordering and propagation.

## Emergency Workarounds

### Use Local-Path for Critical Workloads
```yaml
storageClassName: local-path  # Instead of longhorn-replicated
```

### Manual Volume Creation
For existing Longhorn volumes, manually mount them on nodes and use hostPath volumes as temporary workaround.

## Related Issues & Resources

1. **Longhorn GitHub Issues**:
   - Search for: "k3s kubelet path csi mount"
   - Known issue: CSI assumes standard Kubernetes paths

2. **K3s Documentation**:
   - Custom kubelet configuration
   - Storage driver compatibility

3. **Community Forums**:
   - Rancher forums K3s + Longhorn topics
   - SUSE support if available

## Priority for Next Session

1. **CRITICAL**: Resolve CSI mount issue or migrate to alternative storage
2. **HIGH**: Complete monitoring stack deployment
3. **MEDIUM**: Migrate remaining workloads from NFS
4. **LOW**: Clean up test pods and failed deployments

## Session Notes

- Mixed K3s versions: v1.32.5 (master, k3s2, k3s3) and v1.30.13 (k3s1)
- Downgrading k3s1 to v1.30.13 did NOT fix the issue
- Issue affects ALL K3s versions tested
- Emergency monitoring deployed using local-path works perfectly
- The bind mount approach partially works but mount operations still fail

## Contact & Escalation

If stuck for >2 hours:
1. Check Longhorn Slack/Discord for K3s specific channels
2. Consider opening GitHub issue with full reproduction steps
3. Evaluate switching to alternative storage solution

---
**Last Updated**: June 14, 2025
**Session Duration**: 48 hours
**Blocker Status**: UNRESOLVED - Requires vendor/community support