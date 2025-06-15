#!/bin/bash
echo "Force cleaning Longhorn resources..."

# Remove finalizers from all stuck resource types
for resource in engineimages engines nodes orphans replicas snapshots volumeattachments volumes; do
    echo "Cleaning $resource.longhorn.io..."
    kubectl get $resource.longhorn.io -n longhorn-system -o name | while read item; do
        kubectl patch $item -n longhorn-system -p '{"metadata":{"finalizers":[]}}' --type=merge || true
    done
done

# Also clean other Longhorn resources
for resource in backups backupvolumes backuptargets backingimages backingimagemanagers instancemanagers sharemanagers settings recurringjobs supportbundles systembackups systemrestores; do
    echo "Cleaning $resource.longhorn.io..."
    kubectl get $resource.longhorn.io -n longhorn-system -o name 2>/dev/null | while read item; do
        kubectl patch $item -n longhorn-system -p '{"metadata":{"finalizers":[]}}' --type=merge || true
    done
done

echo "All finalizers removed"