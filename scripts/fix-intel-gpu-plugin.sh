#!/bin/bash
# Fix Intel GPU plugin for K3s by creating symlinks on nodes

echo "Fixing Intel GPU plugin kubelet paths for K3s..."

# Get nodes with Intel GPU
NODES=$(kubectl get nodes -l intel.feature.node.kubernetes.io/gpu=true -o jsonpath='{.items[*].metadata.name}')

for NODE in $NODES; do
    echo "Creating symlink on node: $NODE"
    
    # Create a debug pod to fix the path
    kubectl run fix-gpu-$NODE --image=busybox --restart=Never --overrides='{
      "spec": {
        "nodeName": "'$NODE'",
        "hostPID": true,
        "containers": [{
          "name": "fix",
          "image": "busybox",
          "command": ["sh", "-c", "
            mkdir -p /host/var/lib/kubelet/device-plugins
            if [ ! -e /host/var/lib/kubelet/device-plugins/kubelet.sock ]; then
              ln -sf /var/lib/rancher/k3s/agent/kubelet/device-plugins/kubelet.sock /host/var/lib/kubelet/device-plugins/kubelet.sock
            fi
            if [ ! -e /host/var/lib/kubelet/device-plugins/DEPRECATION ]; then
              ln -sf /var/lib/rancher/k3s/agent/kubelet/device-plugins/DEPRECATION /host/var/lib/kubelet/device-plugins/DEPRECATION
            fi
            sleep 5
          "],
          "volumeMounts": [{
            "name": "host",
            "mountPath": "/host"
          }],
          "securityContext": {
            "privileged": true
          }
        }],
        "volumes": [{
          "name": "host",
          "hostPath": {
            "path": "/"
          }
        }]
      }
    }' --rm=true
    
    # Wait for completion
    sleep 10
done

# Restart Intel GPU plugin pods
echo "Restarting Intel GPU plugin pods..."
kubectl delete pods -n intel-device-plugins-system -l name=intel-gpu-plugin

echo "Waiting for pods to restart..."
sleep 15

# Check status
echo "Current status:"
kubectl get pods -n intel-device-plugins-system -l name=intel-gpu-plugin
kubectl get nodes -o custom-columns=NAME:.metadata.name,GPU:.status.allocatable."gpu\.intel\.com/i915"