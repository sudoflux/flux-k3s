# Longhorn CSI K3s Kubelet Path Fix

## Problem
Longhorn CSI driver was failing to mount volumes on K3s due to a path mismatch:
- K3s uses: `/var/lib/rancher/k3s/agent/kubelet/`
- Longhorn expects: `/var/lib/kubelet/`

This caused pods with Longhorn PVCs to get stuck in `ContainerCreating` state with error:
```
lstat /var/lib/kubelet/pods/.../mount: no such file or directory
```

## Solution
Configure K3s to use the standard kubelet path by adding the following to `/etc/rancher/k3s/config.yaml`:

```yaml
kubelet-arg:
  - "root-dir=/var/lib/kubelet"
```

For master nodes with existing configuration, ensure proper YAML formatting:
```yaml
# K3s configuration
kube-apiserver-arg:
  - "feature-gates=AuthorizeNodeWithSelectors=false"
kubelet-arg:
  - "root-dir=/var/lib/kubelet"
```

## Implementation Steps

1. **Backup existing configuration**:
   ```bash
   sudo cp -a /etc/rancher/k3s /etc/rancher/k3s.backup.$(date +%Y%m%d-%H%M%S)
   ```

2. **Add/update configuration** on each node:
   ```bash
   echo 'kubelet-arg:
     - "root-dir=/var/lib/kubelet"' | sudo tee -a /etc/rancher/k3s/config.yaml
   ```

3. **Restart K3s services**:
   - Master: `sudo systemctl restart k3s`
   - Workers: `sudo systemctl restart k3s-agent`

4. **Verify the fix** by creating a test pod with Longhorn volume

## Important Notes

- This fix was successfully tested and resolves new Longhorn volume mounts
- Existing PVCs created before the fix may still have issues and might need to be recreated
- The CSI plugin may need to be restarted after applying the fix: 
  ```bash
  kubectl delete pods -n longhorn-system -l app=longhorn-csi-plugin
  ```

## Status
- ✅ Fix applied to all nodes (k3s-master1, k3s1, k3s2, k3s3)
- ✅ New Longhorn volumes mount successfully
- ⚠️  Some existing monitoring PVCs may need migration or recreation

## Next Steps
If existing PVCs continue to fail:
1. Consider using the PVC migration guide to move data to new PVCs
2. Or temporarily use local-path provisioner for critical workloads
3. Investigate OpenEBS as a potential alternative if issues persist