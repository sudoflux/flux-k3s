#!/bin/bash
# Script to clean up old NFS PVCs after confirming apps are using Longhorn

echo "=== Old PVC Cleanup Script ==="
echo "WARNING: This will delete old NFS PVCs in the media namespace"
echo "Make sure all apps are successfully running on Longhorn storage first!"
echo ""
read -p "Are you sure you want to proceed? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Cleanup cancelled."
    exit 0
fi

# List of old NFS PVCs to remove
OLD_PVCS=(
    "bazarr-config-pvc"
    "jellyfin-config-pvc"
    "lidarr-config-pvc"
    "overseerr-config-pvc"
    "plex-config-pvc"
    "prowlarr-config-pvc"
    "radarr-config-pvc"
    "recyclarr-config-pvc"
    "sabnzbd-config-pvc"
    "sonarr-config-pvc"
    "whisparr-config-pvc"
)

echo "Deleting old NFS PVCs..."
for pvc in "${OLD_PVCS[@]}"; do
    echo "Deleting $pvc..."
    kubectl delete pvc "$pvc" -n media
done

# Clean up emergency PVCs in monitoring namespace (after monitoring is fixed)
echo ""
echo "Cleaning up emergency monitoring PVCs..."
kubectl delete pvc loki-storage-emergency-loki-0 prometheus-storage-emergency-prometheus-0 -n monitoring

echo ""
echo "Cleanup complete!"
echo "Note: k3s-data-pvc is kept as it's the main media storage (30TB)"