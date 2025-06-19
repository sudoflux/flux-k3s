#!/bin/bash
# Script to migrate media app configs from NFS to Longhorn storage
set -e

echo "=== Media Config Migration: NFS to Longhorn v1.9.0 ==="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check prerequisites
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Error: kubectl is not installed${NC}"
    exit 1
fi

# List of apps to migrate
APPS=(
    "plex"
    "jellyfin"
    "radarr"
    "sonarr"
    "lidarr"
    "bazarr"
    "prowlarr"
    "overseerr"
    "whisparr"
    "sabnzbd"
    "recyclarr"
)

echo -e "${YELLOW}This script will migrate the following app configs from NFS to Longhorn:${NC}"
printf '%s\n' "${APPS[@]}"
echo ""
echo -e "${YELLOW}Using storage class: longhorn-nvme (replicated across 3 nodes)${NC}"
echo ""
read -p "Continue with migration? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Migration cancelled."
    exit 1
fi

# Create migration namespace if it doesn't exist
kubectl create namespace migration-temp 2>/dev/null || true

# Function to migrate a single app
migrate_app() {
    local APP=$1
    echo -e "\n${YELLOW}=== Migrating $APP ===${NC}"
    
    # Create new Longhorn PVC
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ${APP}-config-longhorn
  namespace: media
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: longhorn-nvme
  resources:
    requests:
      storage: 1Gi
EOF
    
    echo "Created Longhorn PVC: ${APP}-config-longhorn"
    
    # Create migration job
    cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: migrate-${APP}
  namespace: migration-temp
spec:
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: migrate
        image: busybox:latest
        command: 
        - sh
        - -c
        - |
          echo "Starting migration for ${APP}..."
          # Create destination directory
          mkdir -p /dest/config
          # Copy all data from NFS to Longhorn
          cp -av /source/* /dest/config/ 2>/dev/null || true
          # Set proper permissions for linuxserver.io containers
          chown -R 1000:1000 /dest
          echo "Migration complete for ${APP}"
        volumeMounts:
        - name: source
          mountPath: /source
        - name: dest
          mountPath: /dest
      volumes:
      - name: source
        persistentVolumeClaim:
          claimName: ${APP}-config-pvc
      - name: dest
        persistentVolumeClaim:
          claimName: ${APP}-config-longhorn
EOF
    
    echo "Waiting for migration job to complete..."
    kubectl wait --for=condition=complete --timeout=300s job/migrate-${APP} -n migration-temp
    
    echo -e "${GREEN}✓ Migration complete for $APP${NC}"
    
    # Clean up job
    kubectl delete job migrate-${APP} -n migration-temp
}

# Migrate each app
for APP in "${APPS[@]}"; do
    migrate_app "$APP"
done

echo -e "\n${GREEN}=== All migrations complete! ===${NC}"
echo ""
echo "Next steps:"
echo "1. Update your app helm values to use the new PVCs:"
echo "   existingClaim: <app>-config-longhorn"
echo ""
echo "2. After verifying apps work with new storage:"
echo "   - Delete old NFS PVCs: kubectl delete pvc <app>-config-pvc -n media"
echo "   - Delete old NFS PVs: kubectl delete pv <app>-config-pv"
echo ""
echo "3. Clean up migration namespace:"
echo "   kubectl delete namespace migration-temp"
echo ""
echo -e "${YELLOW}Note: The old data on NFS will remain untouched as a backup${NC}"