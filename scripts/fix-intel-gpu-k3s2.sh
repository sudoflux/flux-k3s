#!/bin/bash
# Create a socat proxy to forward kubelet.sock on k3s2

kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: kubelet-proxy-script
  namespace: kube-system
data:
  start-proxy.sh: |
    #!/bin/sh
    # Find the actual K3s kubelet socket
    K3S_SOCKET="/var/lib/rancher/k3s/agent/kubelet/pods"
    LEGACY_SOCKET="/var/lib/kubelet/device-plugins/kubelet.sock"
    
    # Create directory if it doesn't exist
    mkdir -p /var/lib/kubelet/device-plugins
    
    # Remove any existing socket
    rm -f \$LEGACY_SOCKET
    
    # Start socat to proxy connections
    # Note: Using the pod-resources socket which is what device plugins actually need
    exec socat UNIX-LISTEN:\$LEGACY_SOCKET,fork,reuseaddr,mode=666 UNIX-CONNECT:/var/lib/rancher/k3s/agent/kubelet/pod-resources/kubelet.sock
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: kubelet-proxy
  namespace: kube-system
spec:
  selector:
    matchLabels:
      name: kubelet-proxy
  template:
    metadata:
      labels:
        name: kubelet-proxy
    spec:
      nodeSelector:
        kubernetes.io/hostname: k3s2
      hostNetwork: true
      hostPID: true
      containers:
      - name: proxy
        image: alpine/socat:1.7.4.4
        command: ["/bin/sh", "/scripts/start-proxy.sh"]
        volumeMounts:
        - name: script
          mountPath: /scripts
        - name: kubelet-legacy
          mountPath: /var/lib/kubelet
        - name: kubelet-k3s
          mountPath: /var/lib/rancher/k3s/agent/kubelet
        securityContext:
          privileged: true
      volumes:
      - name: script
        configMap:
          name: kubelet-proxy-script
          defaultMode: 0755
      - name: kubelet-legacy
        hostPath:
          path: /var/lib/kubelet
          type: DirectoryOrCreate
      - name: kubelet-k3s
        hostPath:
          path: /var/lib/rancher/k3s/agent/kubelet
          type: Directory
      tolerations:
      - operator: Exists
EOF

echo "Waiting for proxy to start..."
sleep 10

# Delete Intel GPU plugin pod to restart it
kubectl delete pod -n intel-device-plugins-system -l name=intel-gpu-plugin

echo "Checking status..."
sleep 15
kubectl get pods -n intel-device-plugins-system -l name=intel-gpu-plugin -o wide
kubectl get nodes -o custom-columns=NAME:.metadata.name,GPU:.status.allocatable."gpu\.intel\.com/i915"