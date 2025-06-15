#!/bin/bash

set -e

echo "=== Monitoring Stack Migration to local-path Storage ==="
echo "This script will migrate monitoring PVCs from longhorn-nvme to local-path"
echo "to avoid fsGroup permission issues."
echo ""

# Check if monitoring namespace exists
if ! kubectl get namespace monitoring &>/dev/null; then
    echo "Error: monitoring namespace not found"
    exit 1
fi

echo "Current PVCs in monitoring namespace:"
kubectl get pvc -n monitoring

echo ""
read -p "Do you want to proceed with the migration? (yes/no): " confirm
if [[ "$confirm" != "yes" ]]; then
    echo "Migration cancelled"
    exit 0
fi

echo ""
echo "Step 1: Scaling down monitoring workloads..."
kubectl scale statefulset -n monitoring prometheus-kube-prometheus-stack-prometheus --replicas=0
kubectl scale statefulset -n monitoring alertmanager-kube-prometheus-stack-alertmanager --replicas=0
kubectl scale deployment -n monitoring kube-prometheus-stack-grafana --replicas=0

echo "Waiting for pods to terminate..."
kubectl wait --for=delete pod -n monitoring -l app.kubernetes.io/name=prometheus --timeout=60s || true
kubectl wait --for=delete pod -n monitoring -l app.kubernetes.io/name=alertmanager --timeout=60s || true
kubectl wait --for=delete pod -n monitoring -l app.kubernetes.io/name=grafana --timeout=60s || true

echo ""
echo "Step 2: Deleting existing PVCs..."
kubectl delete pvc -n monitoring --all

echo ""
echo "Step 3: Applying local-path patch to HelmRelease..."
kubectl patch helmrelease -n monitoring kube-prometheus-stack --type merge --patch-file=/home/josh/flux-k3s/scripts/monitoring-local-path-patch.yaml

echo ""
echo "Step 4: Triggering Flux reconciliation..."
flux reconcile helmrelease -n monitoring kube-prometheus-stack --with-source

echo ""
echo "Step 5: Waiting for new PVCs to be created..."
sleep 10
kubectl get pvc -n monitoring

echo ""
echo "Step 6: Scaling up monitoring workloads..."
kubectl scale statefulset -n monitoring prometheus-kube-prometheus-stack-prometheus --replicas=1
kubectl scale statefulset -n monitoring alertmanager-kube-prometheus-stack-alertmanager --replicas=1
kubectl scale deployment -n monitoring kube-prometheus-stack-grafana --replicas=1

echo ""
echo "Migration complete! Checking pod status..."
kubectl get pods -n monitoring

echo ""
echo "NOTE: You may need to reconfigure Grafana dashboards and data sources"
echo "as this is a fresh installation with local-path storage."