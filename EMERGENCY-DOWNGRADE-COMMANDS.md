# Emergency K3s Downgrade Commands
## From v1.32.5+k3s1 to v1.31.9+k3s1

**CRITICAL**: Execute these commands in EXACT order. Do not skip any steps.

---

## Phase 0: Manual Emergency Backup (CRITICAL - DO NOT SKIP)

SSH into k3s-master1 and run:

```bash
# Stop K3s for consistent backup
sudo systemctl stop k3s

# Create backup with timestamp
sudo cp -r /var/lib/rancher/k3s /var/lib/rancher/k3s-backup-v1.32.5-$(date +%Y%m%d-%H%M%S)

# Verify backup exists
sudo ls -la /var/lib/rancher/k3s-backup-*

# Restart K3s
sudo systemctl start k3s

# Wait for API to be ready
sleep 30
kubectl get nodes
```

---

## Phase 1: Restore Cluster Topology (Rejoin k3s3)

### On k3s3:

```bash
# Complete purge of K3s
sudo /usr/local/bin/k3s-agent-uninstall.sh || true
sudo rm -rf /etc/rancher/k3s /var/lib/rancher/k3s /var/lib/kubelet /var/lib/longhorn

# Reinstall K3s agent (current version to match cluster)
export K3S_URL=https://192.168.10.30:6443
export K3S_TOKEN=$(ssh k3s-master1 'sudo cat /var/lib/rancher/k3s/server/node-token')
export INSTALL_K3S_VERSION=v1.32.5+k3s1
curl -sfL https://get.k3s.io | sh -

# Verify agent started
sudo systemctl status k3s-agent
```

### From your workstation:

```bash
# Wait for k3s3 to rejoin
watch kubectl get nodes
# Wait until k3s3 shows as Ready
```

---

## Phase 2: Downgrade Control Plane (k3s-master1)

SSH into k3s-master1 and run:

```bash
# Stop K3s server
sudo systemctl stop k3s

# Downgrade to v1.31.9
export INSTALL_K3S_VERSION=v1.31.9+k3s1
curl -sfL https://get.k3s.io | sh -

# Start K3s server
sudo systemctl start k3s

# Monitor logs (watch for errors)
sudo journalctl -u k3s -f
# Press Ctrl+C after confirming no major errors

# Check status
sudo systemctl status k3s
```

### ROLLBACK PROCEDURE (if master fails):
```bash
# On k3s-master1:
sudo systemctl stop k3s
sudo rm -rf /var/lib/rancher/k3s
sudo mv /var/lib/rancher/k3s-backup-v1.32.5-* /var/lib/rancher/k3s
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=v1.32.5+k3s1 sh -
sudo systemctl start k3s
```

---

## Phase 3: Downgrade Worker Nodes

Execute for each worker node IN ORDER: k3s1, then k3s2, then k3s3

### On k3s1:

```bash
# Stop agent
sudo systemctl stop k3s-agent

# Downgrade
export INSTALL_K3S_VERSION=v1.31.9+k3s1
curl -sfL https://get.k3s.io | sh -

# Start agent
sudo systemctl start k3s-agent

# Verify
sudo systemctl status k3s-agent
```

### Repeat for k3s2:

```bash
# Stop agent
sudo systemctl stop k3s-agent

# Downgrade
export INSTALL_K3S_VERSION=v1.31.9+k3s1
curl -sfL https://get.k3s.io | sh -

# Start agent
sudo systemctl start k3s-agent

# Verify
sudo systemctl status k3s-agent
```

### Repeat for k3s3:

```bash
# Stop agent
sudo systemctl stop k3s-agent

# Downgrade
export INSTALL_K3S_VERSION=v1.31.9+k3s1
curl -sfL https://get.k3s.io | sh -

# Start agent
sudo systemctl start k3s-agent

# Verify
sudo systemctl status k3s-agent
```

---

## Phase 4: Validation and Recovery

From your workstation:

```bash
# Check all nodes are Ready and on v1.31.9
kubectl get nodes

# Verify CSI driver registration (should NOT be null)
kubectl describe csinode k3s3 | grep -A 10 "Drivers:"

# Check Longhorn pods
kubectl get pods -n longhorn-system

# Test volume mount
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: test-downgrade-volume
  namespace: default
spec:
  containers:
  - name: test
    image: busybox
    command: ["sleep", "3600"]
    volumeMounts:
    - name: test
      mountPath: /data
  volumes:
  - name: test
    persistentVolumeClaim:
      claimName: bazarr-config-longhorn
EOF

# Wait and check
sleep 30
kubectl get pod test-downgrade-volume

# If pod is Running, CSI is fixed!
kubectl delete pod test-downgrade-volume

# Resume Flux
flux resume kustomization --all -n flux-system
```

---

## Post-Downgrade Checklist

- [ ] All nodes show v1.31.9+k3s1
- [ ] CSINode objects show Longhorn driver
- [ ] Test pod with Longhorn volume starts successfully
- [ ] Critical applications are running
- [ ] Flux reconciliation resumed
- [ ] Document lessons learned

## Emergency Contacts

If issues arise during downgrade, immediately contact the team through Slack/Discord with:
1. Which phase failed
2. Error messages
3. Current node status

---

Generated: $(date)