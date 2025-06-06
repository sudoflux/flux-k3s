#!/bin/bash

set -e

MEDIA_KUSTOMIZATION="clusters/k3s-home/apps/media/kustomization.yaml"
MEDIA_DIR=$(dirname "$MEDIA_KUSTOMIZATION")

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

if [ ! -f "$MEDIA_KUSTOMIZATION" ]; then
  echo -e "${RED}ERROR: Could not find: $MEDIA_KUSTOMIZATION${NC}"
  echo "Please run this script from the root of your 'flux-k3s' repository."
  exit 1
fi

echo -e "${YELLOW}This script will perform the following actions:${NC}"
echo "1. Create a 'kustomization.yaml' in each application sub-directory (e.g., radarr/, sonarr/)."
echo "2. Overwrite '$MEDIA_KUSTOMIZATION' to point to these new directories."
echo ""
read -p "Are you sure you want to continue? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Operation cancelled."
  exit 1
fi

echo -e "\n${GREEN}---> Processing application sub-directories...${NC}"

# --- NEW, MORE ROBUST PARSING LOGIC ---
# Use awk to find lines containing './', then split by '/' and take the second field.
# This is much more reliable than the previous grep/cut command.
APP_DIRS=$(awk -F/ '/\.\// {print $2}' "$MEDIA_KUSTOMIZATION" | sort -u)

if [ -z "$APP_DIRS" ]; then
    echo -e "${RED}Could not find any application directories to process. Exiting.${NC}"
    exit 1
fi

for APP in $APP_DIRS; do
  APP_PATH="$MEDIA_DIR/$APP"
  if [ -d "$APP_PATH" ]; then
    RESOURCES=$(find "$APP_PATH" -maxdepth 1 -type f \( -name "helmrelease.yaml" -o -name "ingress.yaml" -o -name "httproute.yaml" \) -exec basename {} \; | sed 's/^/  - /')

    if [ -n "$RESOURCES" ]; then
      echo -e "apiVersion: kustomize.config.k8s.io/v1beta1\nkind: Kustomization\nresources:\n$RESOURCES" > "$APP_PATH/kustomization.yaml"
      echo "  [✅ Created] kustomization.yaml for '$APP'"
    else
      echo -e "  [⚠️ Skipped] No resources found in '$APP'"
    fi
  fi
done

echo -e "\n${GREEN}---> Rewriting parent kustomization file...${NC}"

cat > "$MEDIA_KUSTOMIZATION" << EOM
# Media Stack Kustomization
# This kustomization manages all media-related applications
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

# This namespace will be applied to all resources below
namespace: media

resources:
  # Base resources for the media namespace
  - namespace.yaml
  - persistent-volume-claims.yaml
  - common-configmap.yaml

  # --- Application Directories ---
  # Kustomize will now look for a 'kustomization.yaml' inside each of these folders.
EOM

for APP in $APP_DIRS; do
  echo "  - ./$APP" >> "$MEDIA_KUSTOMIZATION"
done

echo "  [✅ Overwritten] $MEDIA_KUSTOMIZATION"
echo -e "\n${GREEN}Refactoring complete! Please review changes with 'git status' and 'git diff'.${NC}"
