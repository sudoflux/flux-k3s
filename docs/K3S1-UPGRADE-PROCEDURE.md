# K3s1 Node Upgrade Procedure

## Current State
- **k3s1**: v1.30.13+k3s1 (OUTDATED)
- **Other nodes**: v1.32.5+k3s1
- **Issue**: Longhorn CSI plugin failing on k3s1 due to version mismatch

## Pre-Upgrade Checklist

1. **Node is cordoned**: ✅ (Already done)
2. **Backup taken**: Create etcd snapshot on control plane node:
   ```bash
   # SSH to k3s-master1
   ssh user@k3s-master1
   sudo k3s etcd-snapshot save --name pre-k3s1-upgrade-$(date +%F-%H%M%S)
   ```

## Upgrade Procedure

### Step 1: Drain the Node
```bash
# From management workstation
kubectl drain k3s1 --ignore-daemonsets --delete-emptydir-data --force
```

### Step 2: SSH to k3s1 and Upgrade
```bash
# SSH to k3s1
ssh user@k3s1

# Check current version
k3s --version

# Upgrade to v1.32.5+k3s1
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=v1.32.5+k3s1 sh -

# Verify upgrade
k3s --version

# Check if kubelet configuration is applied
cat /etc/rancher/k3s/config.yaml | grep kubelet
# Should show: kubelet-arg: ["root-dir=/var/lib/kubelet"]
```

### Step 3: Verify Services
```bash
# Check k3s-agent service
sudo systemctl status k3s-agent

# Check logs for any errors
sudo journalctl -u k3s-agent -n 100
```

### Step 4: Uncordon the Node
```bash
# From management workstation
kubectl uncordon k3s1

# Verify node status
kubectl get nodes k3s1
```

### Step 5: Verify Longhorn CSI
```bash
# Check Longhorn CSI plugin on k3s1
kubectl get pods -n longhorn-system -o wide | grep k3s1

# Should see longhorn-csi-plugin pod Running on k3s1
```

## Post-Upgrade Verification

1. **Check node version**:
   ```bash
   kubectl get nodes -o wide
   ```

2. **Verify Longhorn health**:
   ```bash
   kubectl get pods -n longhorn-system
   ```

3. **Check workloads on k3s1**:
   ```bash
   kubectl get pods --all-namespaces -o wide | grep k3s1
   ```

## Rollback Procedure

If issues occur:
1. Cordon the node again
2. Restore from etcd snapshot on control plane
3. Consider removing and re-adding the node if necessary

## Notes
- The upgrade crosses multiple minor versions (1.30 → 1.32)
- Ensure kubelet configuration persists after upgrade
- Monitor for any API deprecation warnings