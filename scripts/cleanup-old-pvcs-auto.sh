#!/bin/bash
# Script to clean up old NFS PVCs after confirming apps are using Longhorn
# Auto version - no prompts

echo "=== Old PVC Cleanup Script (Auto) ==="
echo "Cleaning up old NFS PVCs in the media namespace"
echo ""

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
    if kubectl get pvc "$pvc" -n media &>/dev/null; then
        echo "Deleting $pvc..."
        kubectl delete pvc "$pvc" -n media --wait=false
    else
        echo "$pvc not found, skipping..."
    fi
done

# Clean up emergency PVCs in monitoring namespace (after monitoring is fixed)
echo ""
echo "Cleaning up emergency monitoring PVCs..."
for pvc in loki-storage-emergency-loki-0 prometheus-storage-emergency-prometheus-0; do
    if kubectl get pvc "$pvc" -n monitoring &>/dev/null; then
        echo "Deleting $pvc..."
        kubectl delete pvc "$pvc" -n monitoring --wait=false
    else
        echo "$pvc not found, skipping..."
    fi
done

echo ""
echo "Cleanup complete!"
echo "Note: k3s-data-pvc is kept as it's the main media storage (30TB)"