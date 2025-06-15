#!/bin/bash

# Script to test and validate monitoring alerts configuration

set -e

echo "=== Monitoring Alerts Test Script ==="
echo

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check if a resource exists
check_resource() {
    local resource=$1
    local name=$2
    local namespace=$3
    
    if kubectl get $resource $name -n $namespace &>/dev/null; then
        echo -e "${GREEN}✓${NC} $resource/$name exists in namespace $namespace"
        return 0
    else
        echo -e "${RED}✗${NC} $resource/$name not found in namespace $namespace"
        return 1
    fi
}

# Function to wait for a condition
wait_for_condition() {
    local condition=$1
    local timeout=${2:-300}
    local interval=${3:-5}
    local elapsed=0
    
    while ! eval $condition; do
        if [ $elapsed -ge $timeout ]; then
            return 1
        fi
        sleep $interval
        elapsed=$((elapsed + interval))
    done
    return 0
}

echo "1. Checking PrometheusRule resources..."
echo "======================================="
for rule in longhorn-alerts storage-alerts velero-alerts node-alerts kubernetes-alerts authentik-alerts; do
    check_resource prometheusrule $rule monitoring
done
echo

echo "2. Checking if Prometheus discovered the rules..."
echo "================================================="
# Port forward to Prometheus
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090 &>/dev/null &
PF_PID=$!
sleep 3

# Check if rules are loaded
RULES_COUNT=$(curl -s http://localhost:9090/api/v1/rules | jq '.data.groups[].rules | length' | paste -sd+ | bc 2>/dev/null || echo "0")
if [ "$RULES_COUNT" -gt "0" ]; then
    echo -e "${GREEN}✓${NC} Prometheus loaded $RULES_COUNT alert rules"
else
    echo -e "${RED}✗${NC} No alert rules found in Prometheus"
fi

kill $PF_PID 2>/dev/null || true
echo

echo "3. Checking Alertmanager configuration..."
echo "========================================="
check_resource secret alertmanager-config monitoring
check_resource configmap alertmanager-templates monitoring

# Check Alertmanager pod
AM_POD=$(kubectl get pods -n monitoring -l app.kubernetes.io/name=alertmanager -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$AM_POD" ]; then
    echo -e "${GREEN}✓${NC} Alertmanager pod is running: $AM_POD"
    
    # Check for config errors
    ERRORS=$(kubectl logs -n monitoring $AM_POD --tail=50 2>/dev/null | grep -i error | wc -l)
    if [ "$ERRORS" -eq "0" ]; then
        echo -e "${GREEN}✓${NC} No errors in Alertmanager logs"
    else
        echo -e "${YELLOW}⚠${NC} Found $ERRORS error(s) in Alertmanager logs"
    fi
else
    echo -e "${RED}✗${NC} Alertmanager pod not found"
fi
echo

echo "4. Testing sample alerts..."
echo "==========================="
echo "Creating test resources to trigger alerts..."

# Test PVC pending alert
cat <<EOF | kubectl apply -f - &>/dev/null
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-pending-pvc
  namespace: default
  labels:
    test: monitoring-alerts
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: non-existent-storage-class
  resources:
    requests:
      storage: 1Gi
EOF
echo -e "${GREEN}✓${NC} Created test PVC (should trigger PersistentVolumeClaimPending alert)"

# Test crash loop pod
cat <<EOF | kubectl apply -f - &>/dev/null
apiVersion: v1
kind: Pod
metadata:
  name: test-crashloop-pod
  namespace: default
  labels:
    test: monitoring-alerts
spec:
  containers:
  - name: crashloop
    image: busybox
    command: ["sh", "-c", "exit 1"]
  restartPolicy: Always
EOF
echo -e "${GREEN}✓${NC} Created test pod (should trigger PodCrashLooping alert)"
echo

echo "5. Waiting for alerts to fire (this may take a few minutes)..."
echo "=============================================================="
echo "You can check active alerts at:"
echo "  - Prometheus: kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090"
echo "  - Alertmanager: kubectl port-forward -n monitoring svc/kube-prometheus-stack-alertmanager 9093:9093"
echo

echo "6. Cleanup test resources..."
echo "============================"
read -p "Press Enter to clean up test resources..."

kubectl delete pvc test-pending-pvc -n default --ignore-not-found=true
kubectl delete pod test-crashloop-pod -n default --ignore-not-found=true
echo -e "${GREEN}✓${NC} Test resources cleaned up"
echo

echo "=== Alert Configuration Summary ==="
echo "=================================="
echo "Total PrometheusRules: $(kubectl get prometheusrules -n monitoring --no-headers | wc -l)"
echo "Alert Categories:"
echo "  - Longhorn storage monitoring"
echo "  - CSI and PVC monitoring"
echo "  - Velero backup monitoring"
echo "  - Node resource monitoring"
echo "  - Kubernetes workload monitoring"
echo "  - Authentik authentication monitoring"
echo
echo "Alert routing configured for:"
echo "  - Critical alerts (immediate notification)"
echo "  - Component-based routing (storage, backup, security)"
echo "  - Severity-based escalation"
echo
echo -e "${GREEN}✓${NC} Alert configuration test completed!"