# Tasks for Next AI Session

## Context
This document created 2025-06-13 after completing Week 3 observability implementation.
Desktop system going down for 10GbE NIC replacement.

## Immediate Tasks After System Restart

### 1. Fix k3s3 Longhorn CSI Driver Issue
- **Problem**: CSINode k3s3 shows `drivers: null`, preventing Longhorn volumes
- **Impact**: Monitoring stack using local-path storage as workaround
- **Action**: Debug why CSI driver won't register on k3s3
- **Test**: `kubectl get csinode k3s3 -o yaml | grep drivers`

### 2. Implement WSL2 GPU Node (After NIC Replacement)
- **Goal**: Add RTX 4090 to cluster via dedicated WSL2 instance
- **Plan**: See `docs/wsl2-gpu-node-plan.md` for detailed steps
- **Script**: Use `docs/setup-wsl-k3s-node.ps1` from Windows PowerShell

### 3. Configure Offsite Backups
- **Current**: Velero backing up to local MinIO only
- **Needed**: Configure Wasabi or B2 for offsite backup
- **Credentials**: User needs to provide cloud storage credentials

### 4. Revert Monitoring to Longhorn Storage
- **After**: k3s3 CSI driver is fixed
- **Files**: Update helm-release.yaml files in monitoring stack
- **Change**: Switch from local-path back to longhorn storage classes

## Current Cluster State

### Working Services
- All media apps (Jellyfin, Plex, *arr stack)
- AI stack (Ollama, Open WebUI, Automatic1111)
- Authentication (Authentik - but 2FA not enabled)
- Storage (Longhorn - except on k3s3)
- Backups (Velero with local MinIO)
- Monitoring (Prometheus, Grafana, Loki)

### Known Issues
1. k3s3 Longhorn CSI driver not registered
2. Monitoring using local-path storage (temporary)
3. No offsite backups configured
4. No TLS/HTTPS (HTTP only)

### Access Points
- Grafana: http://grafana.fletcherlabs.net
- All services: http://<service>.fletcherlabs.net
- SSH: Direct to any node (k3s1, k3s2, k3s3, k3s-master1)

## Important Notes
- SOPS age key at `~/.config/sops/age/keys.txt` - BACKED UP?
- Do NOT enable Authentik 2FA until all infrastructure work complete
- Tesla T4 is in k3s3, RTX 4090 is in desktop (not yet in cluster)