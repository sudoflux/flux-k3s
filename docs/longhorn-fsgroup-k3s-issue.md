# Longhorn fsGroup Issue with K3s

## Issue Summary
Longhorn v1.9.0 is successfully upgraded, but fsGroup volumes fail to mount on K3s due to kubelet path mismatch.

## Root Cause
K3s uses `/var/lib/rancher/k3s/agent/kubelet` instead of the standard `/var/lib/kubelet`. While Longhorn CSI plugin is configured with the correct path, the kubelet's fsGroup application still looks for the standard path, causing:

```
applyFSGroup failed for vol pvc-xxx: lstat /var/lib/kubelet/pods/.../mount: no such file or directory
```

## Current Workaround
Grafana and other services requiring fsGroup are using local-path storage instead of Longhorn.

## Permanent Solutions
1. **Symlink workaround**: Create symlinks on all nodes:
   ```bash
   sudo ln -s /var/lib/rancher/k3s/agent/kubelet /var/lib/kubelet
   ```

2. **Wait for CSI fsGroupPolicy**: Future Longhorn versions may fully delegate fsGroup handling to CSI, avoiding the kubelet path issue.

3. **Use local-path storage**: Current approach for fsGroup workloads.

## References
- https://longhorn.io/kb/troubleshooting-volume-with-rwx-access-mode-fails-to-mount/
- https://github.com/longhorn/longhorn/issues/2644