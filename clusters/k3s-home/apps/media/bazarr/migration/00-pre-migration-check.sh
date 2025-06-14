#!/bin/bash
# Pre-migration verification script for Bazarr

echo "=== Bazarr Pre-Migration Check ==="
echo ""

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl not found. Please install kubectl."
    exit 1
fi

# Check namespace
echo "1. Checking namespace..."
if kubectl get namespace media &> /dev/null; then
    echo "✅ Namespace 'media' exists"
else
    echo "❌ Namespace 'media' not found"
    exit 1
fi

# Check current Bazarr deployment
echo ""
echo "2. Checking Bazarr deployment..."
DEPLOYMENT_STATUS=$(kubectl get deployment bazarr -n media -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null)
if [ "$DEPLOYMENT_STATUS" = "True" ]; then
    echo "✅ Bazarr deployment is available"
    CURRENT_REPLICAS=$(kubectl get deployment bazarr -n media -o jsonpath='{.spec.replicas}')
    echo "   Current replicas: $CURRENT_REPLICAS"
else
    echo "⚠️  Bazarr deployment is not available"
fi

# Check current PVC
echo ""
echo "3. Checking current PVC..."
if kubectl get pvc bazarr-config-pvc -n media &> /dev/null; then
    echo "✅ Current PVC 'bazarr-config-pvc' exists"
    PVC_SIZE=$(kubectl get pvc bazarr-config-pvc -n media -o jsonpath='{.status.capacity.storage}')
    echo "   Size: $PVC_SIZE"
else
    echo "❌ Current PVC not found"
    exit 1
fi

# Check Longhorn
echo ""
echo "4. Checking Longhorn..."
if kubectl get storageclass longhorn-nvme &> /dev/null; then
    echo "✅ StorageClass 'longhorn-nvme' exists"
else
    echo "❌ StorageClass 'longhorn-nvme' not found"
    exit 1
fi

# Check for existing Longhorn PVC
echo ""
echo "5. Checking for existing Longhorn PVC..."
if kubectl get pvc bazarr-config-longhorn -n media &> /dev/null 2>&1; then
    echo "⚠️  Longhorn PVC already exists. Please delete it first:"
    echo "   kubectl delete pvc bazarr-config-longhorn -n media"
    exit 1
else
    echo "✅ Longhorn PVC does not exist (good)"
fi

# Check recent backups
echo ""
echo "6. Checking recent backups..."
RECENT_BACKUPS=$(kubectl get backup -n velero --sort-by=.metadata.creationTimestamp | tail -5)
echo "Recent backups:"
echo "$RECENT_BACKUPS"

# Check disk space on nodes
echo ""
echo "7. Checking node disk space..."
kubectl get nodes -o custom-columns=NAME:.metadata.name,DISK:.status.allocatable.ephemeral-storage

# Final check
echo ""
echo "=== Pre-Migration Summary ==="
echo "✅ All basic checks passed"
echo ""
echo "⚠️  IMPORTANT: Before proceeding:"
echo "   1. Ensure no active subtitle downloads in Bazarr"
echo "   2. Note the current Bazarr version"
echo "   3. Have checked recent backup is successful"
echo "   4. Ready to monitor the migration"
echo ""
echo "Ready to proceed? (Type 'yes' to continue)"
read -r response
if [ "$response" != "yes" ]; then
    echo "Migration cancelled."
    exit 1
fi

echo ""
echo "✅ Pre-migration checks complete. Proceed with migration steps."