# Longhorn fsGroup Fix Attempt - June 16, 2025

## Problem Summary
Longhorn v1.6.2 volumes with fsGroup fail to mount because:
1. K3s uses `/var/lib/rancher/k3s/agent/kubelet/` for kubelet operations
2. Longhorn CSI mounts volumes in the K3s path correctly
3. But kubelet's fsGroup code looks for volumes in `/var/lib/kubelet/pods/*/volumes/kubernetes.io~csi/*/mount`
4. The `/var/lib/kubelet` directories exist but CSI volumes aren't mounted there

## Investigation Results
- All nodes have `/var/lib/kubelet` directories (created during previous incident)
- These directories have some content but CSI mounts are missing
- The actual CSI mounts happen in `/var/lib/rancher/k3s/agent/kubelet/pods/`
- Simply having the directory isn't enough - we need the CSI mount points

## Attempted Solutions

### 1. K3s Kubelet Configuration (Not Viable)
- Attempted to use `--kubelet-arg "root-dir=/var/lib/kubelet"`
- This would require draining all nodes and could break existing functionality
- Too risky without staging environment

### 2. Symlink Approach (Next Attempt)
Since modifying K3s configuration is risky, we'll try a more targeted symlink approach:
- Create symlinks for the CSI mount points specifically
- This requires linking the pod volumes from K3s path to standard path

## Decision
Proceeding with targeted symlink approach as it's less invasive than:
1. Modifying K3s configuration (high risk)
2. Upgrading Longhorn through 3 versions (very high risk)