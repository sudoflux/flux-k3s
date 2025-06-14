# CSI Troubleshooting Guide

## Overview
This guide consolidates past resolution attempts and provides a decision tree for troubleshooting the Longhorn CSI driver registration issue on k3s nodes (notably k3s3).

**Critical Context**: K3s v1.32.5 appears to have a fundamental incompatibility with Longhorn v1.6.2's CSI driver registration mechanism.

## Common Issue
- **Error Message:**  
  ```
  MountVolume.MountDevice failed: driver name driver.longhorn.io not found in the list of registered CSI drivers
  ```
- **Secondary Error:**
  ```
  AttachVolume.Attach failed for volume "pvc-xxx": CSINode k3s3 does not contain driver driver.longhorn.io
  ```

## Failed Resolution Attempts (Record of what has been tried)

### 1. Disabling AuthorizeNodeWithSelectors Feature Gate
- **Attempt**: Added `--kube-apiserver-arg=feature-gates=AuthorizeNodeWithSelectors=false` to K3s config
- **Commands Used**:
  ```bash
  # On k3s-master1
  sudo vim /etc/rancher/k3s/config.yaml
  sudo systemctl restart k3s
  ```
- **Outcome**: ❌ Did not result in persistent driver registration
- **Logs**: No change in CSINode object

### 2. Node Evacuation and Rejoin
- **Attempt**: Drained and rejoined node k3s3
- **Commands Used**:
  ```bash
  kubectl cordon k3s3
  kubectl drain k3s3 --ignore-daemonsets --delete-emptydir-data
  # On k3s3
  sudo /usr/local/bin/k3s-agent-uninstall.sh
  curl -sfL https://get.k3s.io | K3S_URL=https://192.168.10.30:6443 K3S_TOKEN=xxx sh -
  ```
- **Outcome**: ❌ Issue reappeared immediately after rejoin
- **Observation**: CSI driver briefly registered during join but disappeared

### 3. Downgrade to K3s v1.31.9
- **Attempt**: Cluster-wide downgrade following emergency procedures
- **Outcome**: ❌ API instability, version skew between master and workers
- **Recovery**: Rolled back via VM snapshot
- **Lesson**: Downgrade requires careful coordination of all nodes

### 4. Manual CSINode Patching
- **Attempt**: Manually patched CSINode object to force registration
- **Commands Used**:
  ```bash
  kubectl patch csinode k3s3 --type='json' -p='[{"op": "add", "path": "/spec/drivers", "value": [{"name": "driver.longhorn.io", "nodeID": "k3s3", "topologyKeys": ["topology.longhorn.io/zone"]}]}]'
  ```
- **Outcome**: ❌ Allowed attach but mounting still failed
- **Error**: `Volume has not been staged yet`

## Decision Tree for Next Steps

### 1. Confirm Error State
```bash
# Check CSI registration
kubectl get csinode k3s3 -o yaml | grep -A10 "spec:"

# Expected bad output:
spec:
  drivers: null  # or missing entirely

# Check Longhorn driver pods
kubectl get pods -n longhorn-system -l app=longhorn-csi-plugin -o wide
```

### 2. Check Logs and Environment
```bash
# Node logs (SSH to k3s3)
sudo journalctl -u k3s-agent -n 500 | grep -E "(csi|longhorn|driver|volume)"

# Longhorn CSI plugin logs
kubectl logs -n longhorn-system -l app=longhorn-csi-plugin --tail=200

# K3s kubelet logs
sudo journalctl -u k3s-agent | grep kubelet | tail -100
```

### 3. Investigate Root Cause

#### Check KUBELET_ROOT_DIR Mismatch
```bash
# Check Longhorn's expected path
kubectl get cm -n longhorn-system longhorn-default-setting -o yaml | grep KUBELET_ROOT_DIR

# Check actual kubelet path on k3s3
ssh k3s3 'sudo ls -la /var/lib/kubelet/plugins/'
ssh k3s3 'sudo ls -la /var/lib/rancher/k3s/agent/kubelet/plugins/'

# If mismatch found, update Longhorn setting:
kubectl edit cm -n longhorn-system longhorn-default-setting
# Change KUBELET_ROOT_DIR to match K3s path
```

#### Verify CSI Socket Locations
```bash
# On k3s3
sudo find /var/lib -name "*.sock" | grep csi
sudo ls -la /var/lib/kubelet/plugins_registry/
```

### 4. Resolution Attempts (In Order)

#### Option A: KUBELET_ROOT_DIR Fix (Least Invasive)
1. Update Longhorn ConfigMap with correct path
2. Restart Longhorn components:
   ```bash
   kubectl rollout restart deployment -n longhorn-system
   kubectl rollout restart daemonset -n longhorn-system
   ```
3. Wait 2-3 minutes and check CSINode again

#### Option B: Restart CSI Components
```bash
# Force restart all CSI components
kubectl delete pods -n longhorn-system -l app=longhorn-csi-plugin
kubectl delete pods -n longhorn-system -l app=csi-attacher
kubectl delete pods -n longhorn-system -l app=csi-provisioner

# Monitor recreation
kubectl get pods -n longhorn-system -w
```

#### Option C: Test Longhorn v1.9.0 (Medium Risk)
1. Create backup of current Longhorn settings
2. Update Longhorn HelmRelease to v1.9.0
3. Test on single PVC before full migration

#### Option D: K3s Downgrade to v1.30.x (High Risk)
1. Follow `/home/josh/flux-k3s/EMERGENCY-DOWNGRADE-COMMANDS.md`
2. Target v1.30.8+k3s1 (last confirmed working)
3. Coordinate all nodes simultaneously

### 5. Validation Tests

#### Quick Test
```yaml
# Save as test-csi.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-csi-quick
  namespace: default
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: longhorn-nvme
  resources:
    requests:
      storage: 100Mi
```

#### Full Test
```yaml
# Save as test-csi-full.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-csi-full
  namespace: default
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: longhorn-nvme
  resources:
    requests:
      storage: 1Gi
---
apiVersion: v1
kind: Pod
metadata:
  name: test-csi-pod
  namespace: default
spec:
  nodeSelector:
    kubernetes.io/hostname: k3s3  # Force scheduling to problem node
  containers:
  - name: test
    image: busybox
    command: ["sh", "-c", "echo 'CSI Working!' > /data/test.txt && cat /data/test.txt && sleep 3600"]
    volumeMounts:
    - name: test-vol
      mountPath: /data
  volumes:
  - name: test-vol
    persistentVolumeClaim:
      claimName: test-csi-full
```

### 6. Alternative Storage Options

If Longhorn remains broken:

#### Local-Path (Current Workaround)
- Already in use for monitoring stack
- No replication, node-local only
- Suitable for temporary data

#### OpenEBS
```bash
# Quick install
kubectl apply -f https://openebs.github.io/charts/openebs-operator.yaml
```

#### Rook-Ceph
- More complex but highly reliable
- Requires dedicated disks
- See: https://rook.io/docs/rook/latest/quickstart.html

## Monitoring Commands

```bash
# Watch CSI registration attempts
watch -n 2 'kubectl get csinode -o custom-columns=NAME:.metadata.name,DRIVERS:.spec.drivers[*].name'

# Monitor events
kubectl get events -A --field-selector reason=FailedMount,reason=FailedAttachVolume -w

# Check volume attachment status
kubectl get volumeattachments
```

## Documentation References
- K3s CSI Documentation: https://docs.k3s.io/storage
- Longhorn Troubleshooting: https://longhorn.io/docs/1.6.2/troubleshooting/
- Kubernetes CSI Spec: https://kubernetes-csi.github.io/docs/

## Emergency Contacts
If all resolution attempts fail:
1. Check K3s GitHub issues for v1.32.5 CSI bugs
2. Post in Longhorn Slack with full error logs
3. Consider emergency VM rollback if production impacted

---
**Last Updated**: 2025-06-14  
**Updated By**: AI Team (o3-mini leading documentation effort)