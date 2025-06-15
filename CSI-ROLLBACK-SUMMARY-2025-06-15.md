# CSI Rollback Summary - June 15, 2025

## Problem Summary
The previous team attempted to fix Longhorn CSI issues by changing the kubelet root directory from K3s's default `/var/lib/rancher/k3s/agent/kubelet` to the standard `/var/lib/kubelet`. This created a split-brain state where:
- The kubelet was using the new path
- Longhorn CSI was misconfigured with mixed paths
- Volume mounts were duplicated between old and new paths
- The CSI plugin container had a critical bug (host-dev volume pointing to /sys instead of /dev)

## Root Causes Identified
1. **Path Mismatch**: KUBELET_ROOT_DIR in CSI daemonset didn't match the actual kubelet configuration
2. **Volume Mount Error**: The host-dev volume was incorrectly pointing to `/sys` instead of `/dev`, causing `/dev/null` not found errors
3. **Duplicate Mounts**: The CSI daemonset had duplicate volume mounts for both old and new kubelet paths
4. **State Inconsistency**: Existing volumes were mounted at the old path but kubelet expected them at the new path

## Actions Taken

### 1. Strategic Rollback (Completed)
- Cordoned all nodes to prevent new pod scheduling
- Scaled down all stateful workloads and deployments with PVCs
- Reverted kubelet configuration on all nodes back to K3s defaults:
  - Removed `kubelet-arg: ["root-dir=/var/lib/kubelet"]` from all nodes
  - Preserved the AuthorizeNodeWithSelectors feature gate on master
- Restarted K3s services on all nodes

### 2. Fixed Longhorn CSI Configuration
- Reverted KUBELET_ROOT_DIR environment variables back to `/var/lib/rancher/k3s/agent/kubelet`
- Fixed the host-dev volume to correctly point to `/dev` (was pointing to `/sys`)
- Removed duplicate volume mounts
- Applied the corrected configuration

### 3. Cluster Recovery
- Uncordoned all nodes
- Scaled workloads back up
- CSI plugins are now running properly on all nodes
- Pods are slowly recovering and mounting volumes

## Current Status
- **Nodes**: All 4 nodes are Ready and uncordoned (k3s1 was restored as agent)
- **CSI**: Longhorn CSI plugins are running on all nodes
- **Workloads**: Scaling back up, volumes are being reattached
- **Recovery**: In progress - some pods still in ContainerCreating state as volumes attach

### Additional Fix: k3s1 Node Recovery
- k3s1 was misconfigured as a server instead of agent after the upgrade
- Reinstalled k3s1 as agent joining the existing cluster
- Longhorn components successfully deployed to k3s1

## Lessons Learned
1. **Never change fundamental paths without proper migration**: The kubelet root directory is critical infrastructure
2. **Test thoroughly**: The host-dev volume bug shows inadequate testing
3. **Avoid mixed states**: Having both old and new paths created confusion
4. **Document changes**: The previous team's changes weren't well documented

## Next Steps
1. Monitor pod recovery - volumes should attach over the next 10-15 minutes
2. Once all pods are running, perform Longhorn health check
3. Consider upgrading Longhorn through Helm once stable
4. Clean up `/var/lib/kubelet` directories once no longer in use

## Commands for Monitoring
```bash
# Check pod status
kubectl get pods -A | grep -v Running

# Check volume attachments
kubectl get volumeattachments | grep -v true

# Check Longhorn health
kubectl get pods -n longhorn-system
kubectl get volumes.longhorn.io -n longhorn-system | grep -v attached
```

---
**Recovery Lead**: Claude (AI Assistant)  
**Recovery Method**: Strategic Rollback to K3s Defaults  
**Time**: June 15, 2025, 01:00-01:15 EST