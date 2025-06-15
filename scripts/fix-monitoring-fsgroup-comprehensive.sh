#!/bin/bash

set -e

echo "=== Comprehensive Fix for Monitoring fsGroup Issues ==="
echo "This script provides multiple solutions for the Longhorn CSI fsGroup problem"
echo ""

# Function to check pod status
check_pod_status() {
    echo "Current monitoring pod status:"
    kubectl get pods -n monitoring -l "app.kubernetes.io/name in (prometheus,alertmanager,grafana)"
    echo ""
}

# Function to check for mount errors
check_mount_errors() {
    echo "Checking for mount errors..."
    kubectl describe pod -n monitoring -l "app.kubernetes.io/name in (prometheus,alertmanager)" | grep -E "(MountVolume|fsGroup|Events:)" -A5 | grep -v "^--$" || echo "No mount errors found"
    echo ""
}

# Display current status
echo "=== Current Status ==="
check_pod_status
check_mount_errors

echo "=== Available Solutions ==="
echo "1. Remove fsGroup from StatefulSets (temporary fix)"
echo "2. Apply HelmRelease patch to permanently remove fsGroup"
echo "3. Migrate to local-path storage (data loss)"
echo "4. Recreate PVCs with proper permissions (data loss)"
echo "5. Check and fix Longhorn volume permissions"
echo ""

read -p "Select solution (1-5): " choice

case $choice in
    1)
        echo "=== Solution 1: Removing fsGroup from StatefulSets ==="
        
        # Remove fsGroup from Prometheus
        kubectl patch statefulset -n monitoring prometheus-kube-prometheus-stack-prometheus --type=json -p='[{"op": "remove", "path": "/spec/template/spec/securityContext/fsGroup"}]' 2>/dev/null || \
        kubectl patch statefulset -n monitoring prometheus-kube-prometheus-stack-prometheus --type=merge -p='{"spec":{"template":{"spec":{"securityContext":{"fsGroup":null}}}}}'
        
        # Remove fsGroup from AlertManager
        kubectl patch statefulset -n monitoring alertmanager-kube-prometheus-stack-alertmanager --type=json -p='[{"op": "remove", "path": "/spec/template/spec/securityContext/fsGroup"}]' 2>/dev/null || \
        kubectl patch statefulset -n monitoring alertmanager-kube-prometheus-stack-alertmanager --type=merge -p='{"spec":{"template":{"spec":{"securityContext":{"fsGroup":null}}}}}'
        
        # Restart pods
        kubectl delete pod -n monitoring prometheus-kube-prometheus-stack-prometheus-0 --grace-period=30
        kubectl delete pod -n monitoring alertmanager-kube-prometheus-stack-alertmanager-0 --grace-period=30
        
        echo "Waiting for pods to restart..."
        sleep 20
        check_pod_status
        ;;
        
    2)
        echo "=== Solution 2: Applying HelmRelease Patch ==="
        
        # Apply the patch
        kubectl patch helmrelease -n monitoring kube-prometheus-stack --type merge --patch-file=/home/josh/flux-k3s/scripts/monitoring-remove-fsgroup-patch.yaml
        
        echo "Triggering Flux reconciliation..."
        flux reconcile helmrelease -n monitoring kube-prometheus-stack --with-source
        
        echo "Waiting for changes to apply..."
        sleep 30
        check_pod_status
        ;;
        
    3)
        echo "=== Solution 3: Migrate to local-path storage ==="
        echo "WARNING: This will delete all monitoring data!"
        read -p "Continue? (yes/no): " confirm
        
        if [[ "$confirm" == "yes" ]]; then
            # Scale down
            kubectl scale statefulset -n monitoring prometheus-kube-prometheus-stack-prometheus --replicas=0
            kubectl scale statefulset -n monitoring alertmanager-kube-prometheus-stack-alertmanager --replicas=0
            
            # Wait for pods to terminate
            kubectl wait --for=delete pod -n monitoring -l app.kubernetes.io/name=prometheus --timeout=60s || true
            kubectl wait --for=delete pod -n monitoring -l app.kubernetes.io/name=alertmanager --timeout=60s || true
            
            # Delete PVCs
            kubectl delete pvc -n monitoring prometheus-kube-prometheus-stack-prometheus-db-prometheus-kube-prometheus-stack-prometheus-0
            kubectl delete pvc -n monitoring alertmanager-kube-prometheus-stack-alertmanager-db-alertmanager-kube-prometheus-stack-alertmanager-0
            
            # Apply local-path patch
            kubectl patch helmrelease -n monitoring kube-prometheus-stack --type merge --patch-file=/home/josh/flux-k3s/scripts/monitoring-local-path-patch.yaml
            
            # Reconcile
            flux reconcile helmrelease -n monitoring kube-prometheus-stack --with-source
            
            echo "Waiting for new PVCs..."
            sleep 20
            kubectl get pvc -n monitoring
        fi
        ;;
        
    4)
        echo "=== Solution 4: Recreate PVCs ==="
        echo "WARNING: This will delete monitoring data!"
        read -p "Continue? (yes/no): " confirm
        
        if [[ "$confirm" == "yes" ]]; then
            # Scale down
            kubectl scale statefulset -n monitoring prometheus-kube-prometheus-stack-prometheus --replicas=0
            kubectl scale statefulset -n monitoring alertmanager-kube-prometheus-stack-alertmanager --replicas=0
            
            # Wait for pods to terminate
            sleep 10
            
            # Delete PVCs
            kubectl delete pvc -n monitoring --all
            
            # Scale back up
            kubectl scale statefulset -n monitoring prometheus-kube-prometheus-stack-prometheus --replicas=1
            kubectl scale statefulset -n monitoring alertmanager-kube-prometheus-stack-alertmanager --replicas=1
            
            echo "Waiting for new PVCs to be created..."
            sleep 20
            check_pod_status
        fi
        ;;
        
    5)
        echo "=== Solution 5: Check Longhorn Volume Permissions ==="
        
        # Get volume names
        PROM_VOL=$(kubectl get pv -o json | jq -r '.items[] | select(.spec.claimRef.name=="prometheus-kube-prometheus-stack-prometheus-db-prometheus-kube-prometheus-stack-prometheus-0") | .spec.csi.volumeHandle')
        ALERT_VOL=$(kubectl get pv -o json | jq -r '.items[] | select(.spec.claimRef.name=="alertmanager-kube-prometheus-stack-alertmanager-db-alertmanager-kube-prometheus-stack-alertmanager-0") | .spec.csi.volumeHandle')
        
        echo "Prometheus Volume: $PROM_VOL"
        echo "AlertManager Volume: $ALERT_VOL"
        echo ""
        
        # Check Longhorn volume status
        if [ ! -z "$PROM_VOL" ]; then
            echo "Prometheus volume details:"
            kubectl get volume.longhorn.io -n longhorn-system $PROM_VOL -o yaml | grep -E "(state:|robustness:|frontend:|accessMode:)" || echo "Volume not found"
        fi
        
        if [ ! -z "$ALERT_VOL" ]; then
            echo "AlertManager volume details:"
            kubectl get volume.longhorn.io -n longhorn-system $ALERT_VOL -o yaml | grep -E "(state:|robustness:|frontend:|accessMode:)" || echo "Volume not found"
        fi
        
        echo ""
        echo "Checking CSI driver pods:"
        kubectl get pods -n longhorn-system -l app=csi-provisioner
        kubectl get pods -n longhorn-system -l app=csi-attacher
        ;;
        
    *)
        echo "Invalid choice"
        exit 1
        ;;
esac

echo ""
echo "=== Final Status ==="
check_pod_status
check_mount_errors

echo ""
echo "If the issue persists, consider:"
echo "1. Checking Longhorn CSI driver status: kubectl get pods -n longhorn-system"
echo "2. Reviewing k3s node status: kubectl get nodes"
echo "3. Checking for related issues in: kubectl logs -n longhorn-system -l app=longhorn-manager"