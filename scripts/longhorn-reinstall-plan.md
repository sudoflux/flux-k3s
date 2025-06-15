# Longhorn Reinstall Plan

## Problem Summary
The Longhorn CSI controllers have incorrect architecture due to path changes. The controllers are using hostPath volumes instead of emptyDir with sidecar containers.

## Pre-requisites
1. Ensure all critical data is backed up
2. Document all custom Longhorn settings
3. Save PVC information for recreation

## Clean Reinstall Steps

### 1. Scale Down Workloads
```bash
# Scale down all workloads using Longhorn PVCs
kubectl scale deployment --all -n media --replicas=0
kubectl scale statefulset --all -n monitoring --replicas=0
```

### 2. Backup Volume Information
```bash
# List all Longhorn volumes
kubectl get pv | grep longhorn > /tmp/longhorn-volumes.txt

# Export PVC definitions
kubectl get pvc -A -o yaml > /tmp/all-pvcs-backup.yaml
```

### 3. Uninstall Longhorn
```bash
# Delete the Helm release
helm uninstall longhorn -n longhorn-system

# Wait for namespace cleanup
kubectl delete namespace longhorn-system --wait=true

# Clean up any remaining CRDs
kubectl get crd | grep longhorn | awk '{print $1}' | xargs kubectl delete crd
```

### 4. Clean Node Directories
```bash
# On each node (k3s1, k3s2, k3s3):
sudo rm -rf /var/lib/rancher/k3s/agent/kubelet/plugins/driver.longhorn.io
sudo rm -rf /var/lib/rancher/k3s/agent/kubelet/plugins_registry/driver.longhorn.io
sudo rm -rf /var/lib/longhorn/*
```

### 5. Reinstall Longhorn
```bash
# Update Helm repo
helm repo update longhorn

# Create namespace
kubectl create namespace longhorn-system

# Install with explicit K3s configuration
helm install longhorn longhorn/longhorn \
  --namespace longhorn-system \
  --set csi.kubeletRootDir="/var/lib/rancher/k3s/agent/kubelet" \
  --set defaultSettings.createDefaultDiskLabeledNodes=true \
  --set defaultSettings.defaultReplicaCount=3 \
  --set defaultSettings.defaultDataLocality=best-effort \
  --set ingress.enabled=true \
  --set ingress.host=longhorn.fletcherlabs.net \
  --set ingress.ingressClassName=cilium
```

### 6. Verify Installation
```bash
# Check all pods are running
kubectl get pods -n longhorn-system

# Verify CSI controllers have correct architecture
kubectl get deployment -n longhorn-system csi-attacher -o yaml | grep -A 20 "containers:"
# Should show BOTH csi-attacher AND longhorn-csi-plugin containers

# Check for emptyDir volume (not hostPath)
kubectl get deployment -n longhorn-system csi-attacher -o yaml | grep -A 5 "volumes:"
# Should show emptyDir, not hostPath
```

### 7. Restore Workloads
```bash
# Scale workloads back up
kubectl scale deployment --all -n media --replicas=1
kubectl scale statefulset --all -n monitoring --replicas=1
```

## Expected Result
- CSI controllers will have proper sidecar architecture
- Both containers (attacher + plugin) in same pod
- emptyDir volume for socket communication
- Volume attachments will work correctly