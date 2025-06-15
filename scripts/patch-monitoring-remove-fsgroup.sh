#!/bin/bash

set -e

echo "=== Patching Monitoring StatefulSets to Remove fsGroup ==="
echo "This is a workaround for the Longhorn CSI fsGroup issue"
echo ""

# Function to patch a StatefulSet to remove fsGroup
patch_statefulset() {
    local namespace=$1
    local name=$2
    
    echo "Patching StatefulSet $namespace/$name..."
    
    # Create a JSON patch to remove fsGroup while keeping other security context settings
    cat <<EOF | kubectl patch statefulset -n "$namespace" "$name" --type=json --patch-file=/dev/stdin
[
  {
    "op": "remove",
    "path": "/spec/template/spec/securityContext/fsGroup"
  }
]
EOF
    
    if [ $? -eq 0 ]; then
        echo "Successfully patched $name"
    else
        echo "Failed to patch $name (it might not have fsGroup set)"
    fi
}

# Patch Prometheus StatefulSet
patch_statefulset monitoring prometheus-kube-prometheus-stack-prometheus

# Patch AlertManager StatefulSet
patch_statefulset monitoring alertmanager-kube-prometheus-stack-alertmanager

echo ""
echo "Restarting pods to apply changes..."

# Delete pods to force recreation with new security context
kubectl delete pod -n monitoring prometheus-kube-prometheus-stack-prometheus-0 --grace-period=0 --force 2>/dev/null || true
kubectl delete pod -n monitoring alertmanager-kube-prometheus-stack-alertmanager-0 --grace-period=0 --force 2>/dev/null || true

echo ""
echo "Waiting for pods to restart..."
sleep 10

echo ""
echo "Checking pod status:"
kubectl get pods -n monitoring -l "app.kubernetes.io/name in (prometheus,alertmanager)"

echo ""
echo "Checking for mount errors:"
kubectl describe pod -n monitoring prometheus-kube-prometheus-stack-prometheus-0 | grep -E "(Events:|Warning)" | tail -20
kubectl describe pod -n monitoring alertmanager-kube-prometheus-stack-alertmanager-0 | grep -E "(Events:|Warning)" | tail -20

echo ""
echo "IMPORTANT: This is a temporary workaround. The StatefulSets may be reverted"
echo "by Flux on the next reconciliation. To make this permanent, you need to"
echo "override the fsGroup setting in the HelmRelease values."