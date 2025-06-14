# Longhorn CSI K3s Troubleshooting Deep Dive
## Technical Details for Next Session

### The Exact Problem

When kubelet tries to mount a Longhorn volume, it executes `applyFSGroup` which attempts to `lstat` the mount path. The sequence is:

1. **CSI Plugin Creates Mount**: Successfully creates mount at `/var/lib/rancher/k3s/agent/kubelet/pods/[POD-ID]/volumes/kubernetes.io~csi/[PVC-ID]/mount`

2. **Kubelet Looks for Mount**: Tries to access `/var/lib/kubelet/pods/[POD-ID]/volumes/kubernetes.io~csi/[PVC-ID]/mount`

3. **Path Mismatch**: These are different paths, so kubelet fails with "no such file or directory"

### Evidence from Logs

#### CSI Plugin Logs (WORKING)
```
time="2025-06-14T16:49:40Z" level=info msg="Trying to ensure mount point /var/lib/kubelet/pods/1ed560c5-1da9-4d42-97b5-533ba3c2fdfd/volumes/kubernetes.io~csi/pvc-e472352e-2101-4a90-8986-d6bdea08c590/mount"
time="2025-06-14T16:49:40Z" level=info msg="Mount point /var/lib/kubelet/pods/1ed560c5-1da9-4d42-97b5-533ba3c2fdfd/volumes/kubernetes.io~csi/pvc-e472352e-2101-4a90-8986-d6bdea08c590/mount try opening and syncing dir to make sure it's healthy"
time="2025-06-14T16:49:40Z" level=info msg="NodePublishVolume: rsp: {}"
```

#### Kubelet Error (FAILING)
```
MountVolume.SetUp failed for volume "pvc-e472352e-2101-4a90-8986-d6bdea08c590" : applyFSGroup failed for vol pvc-e472352e-2101-4a90-8986-d6bdea08c590: lstat /var/lib/kubelet/pods/1ed560c5-1da9-4d42-97b5-533ba3c2fdfd/volumes/kubernetes.io~csi/pvc-e472352e-2101-4a90-8986-d6bdea08c590/mount: no such file or directory
```

### Why Bind Mounts Don't Fully Work

1. **Timing Issue**: CSI creates directories AFTER bind mount is established
2. **Mount Propagation**: Even with `rshared`, new subdirectories may not propagate correctly
3. **Process Isolation**: CSI plugin container and kubelet see different mount namespaces

### What Actually Happens

```bash
# CSI Plugin creates:
/var/lib/rancher/k3s/agent/kubelet/pods/[POD-ID]/volumes/kubernetes.io~csi/[PVC-ID]/mount

# Due to bind mount, this SHOULD appear at:
/var/lib/kubelet/pods/[POD-ID]/volumes/kubernetes.io~csi/[PVC-ID]/mount

# But kubelet's lstat() call fails to find it
```

### Test Commands to Verify

```bash
# 1. Create test directory in k3s path
sudo mkdir -p /var/lib/rancher/k3s/agent/kubelet/pods/test-pod/volumes/kubernetes.io~csi/test-pvc/mount

# 2. Check if it appears in standard path
ls -la /var/lib/kubelet/pods/test-pod/volumes/kubernetes.io~csi/test-pvc/mount

# 3. If not visible, bind mount isn't propagating new directories
```

### Deep Investigation Areas

1. **CSI Plugin Source Code**
   - Check if KUBELET_ROOT_DIR env var is actually used for ALL paths
   - Look for hardcoded `/var/lib/kubelet` references
   - File: `csi/node_server.go` in Longhorn repository

2. **Kubelet Configuration**
   - Check if k3s kubelet has different `--root-dir` setting
   - Run: `ps aux | grep kubelet` on k3s node to see actual args

3. **Mount Namespace Investigation**
   ```bash
   # Check mount namespaces
   sudo ls -la /proc/$(pidof k3s)/ns/mnt
   sudo ls -la /proc/$(docker inspect -f '{{.State.Pid}}' longhorn-csi-plugin-xxx)/ns/mnt
   ```

### Alternative Approach: Kubelet Root Dir Change

Instead of making CSI adapt to K3s, make K3s use standard paths:

```yaml
# /etc/rancher/k3s/config.yaml (THEORETICAL - NEEDS TESTING)
kubelet-arg:
  - "--root-dir=/var/lib/kubelet"
  - "--cert-dir=/var/lib/kubelet/pki"
  - "--seccomp-profile-root=/var/lib/kubelet/seccomp"
```

**WARNING**: This would require moving all existing kubelet data!

### Quick Test for Next Session

Before diving deep, try this simple test:

```bash
# 1. Deploy a test pod with emptyDir
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: test-emptydir
  namespace: default
spec:
  containers:
  - name: test
    image: busybox
    command: ["sleep", "3600"]
    volumeMounts:
    - name: test-vol
      mountPath: /data
  volumes:
  - name: test-vol
    emptyDir: {}
EOF

# 2. Find where kubelet created the emptyDir
kubectl get pod test-emptydir -o jsonpath='{.metadata.uid}'
# Then check both paths:
# /var/lib/kubelet/pods/[UID]/volumes/kubernetes.io~empty-dir/
# /var/lib/rancher/k3s/agent/kubelet/pods/[UID]/volumes/kubernetes.io~empty-dir/
```

This will confirm which path kubelet actually uses for volume operations.

### Last Resort Options

1. **Fork Longhorn**: Modify CSI plugin to detect K3s and use correct paths
2. **Wrapper Script**: Create a wrapper that intercepts and rewrites paths
3. **Different K3s Install**: Use `--data-dir=/var/lib/kubelet` during K3s installation
4. **Give Up on Longhorn**: Use alternative storage that's K3s-aware

---
**Critical Finding**: The issue is NOT with CSI registration or driver discovery. The CSI driver works perfectly until the final mount step where kubelet and CSI disagree on filesystem paths.