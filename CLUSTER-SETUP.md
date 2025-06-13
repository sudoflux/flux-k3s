# K3s Homelab Cluster Setup Documentation

## Overview
This document provides a comprehensive overview of the K3s cluster setup, including hardware configuration, software architecture, and operational details. This cluster runs media services using GitOps principles with Flux CD.

## Hardware Configuration

### Physical Nodes

#### Dell R730 (Storage Server)
- **Role**: Hosts VMs and provides NFS storage
- **Storage**: 
  - NVMe storage at `/mnt/nvme_storage` (for app configs)
  - Rust/spinning disk array at `/mnt/rust/media` (for media files)
- **VMs Hosted**: k3s-master1 (and potentially others)
- **Note**: Single point of failure for storage

#### Dell R630 (k3s3)
- **Role**: GPU compute worker node
- **CPU**: Dual Intel Xeon E5-2697A v4 (16 cores each, 32 cores total, 64 threads)
- **RAM**: 384GB DDR4
- **GPU**: NVIDIA Tesla T4 16GB
- **Network**: 10GbE
- **Storage**: 
  - PCIe adapter card with 4x M.2 slots (bifurcation enabled):
    - 2x Intel Optane SSDPEK1A118GA (110GB each) at `/mnt/optane-1` and `/mnt/optane-2`
    - 2x Samsung 980 PRO 1TB NVMe at `/mnt/nvme-1` and `/mnt/nvme-2`
  - 7x SAS SSDs (350GB each) at `/mnt/sas-1` through `/mnt/sas-7`
  - OS drive: 365GB with ~327GB free

#### Dell OptiPlex Micro (k3s1 & k3s2)
- **Role**: Light compute worker nodes
- **CPU**: Intel processors with QuickSync hardware transcoding
- **Storage**: 512GB NVMe each
- **Network**: 2.5GbE
- **Special Feature**: Intel QuickSync for hardware video transcoding

### Virtual Nodes

#### k3s-master1
- **Role**: K3s control plane
- **Type**: VM running on R730
- **Resources**: 8GB RAM, 4 vCPUs
- **Storage**: 24GB root disk
- **OS**: Ubuntu 22.04 LTS

## Cluster Architecture

### Kubernetes Distribution
- **K3s** v1.32.5 (lightweight Kubernetes)
- **CNI**: Cilium (replaced default Flannel)
- **Ingress**: Gateway API with Cilium
- **GitOps**: Flux CD v2

### Important K3s Configuration
- ServiceLB disabled (`--disable=servicelb`) to prevent conflicts with Cilium
- Flannel disabled (`--flannel-backend=none`)
- Network policy disabled (`--disable-network-policy`) as Cilium handles this

### Networking
- **CNI**: Cilium with eBPF
- **Load Balancer**: Cilium L2 announcements and BGP
- **Gateway API**: Main gateway at `192.168.10.224`
- **IP Pool**: `192.168.10.224/28` (192.168.10.224-239)
- **BGP**: Peering with router at 192.168.10.1 (AS 64513)
- **Service Access**: All services use `*.fletcherlabs.net` domains

### Storage Architecture

#### NFS Storage (from R730)
- **Config Storage**: Apps use NFS from `192.168.10.100:/mnt/nvme_storage/<app>`
- **Media Storage**: Jellyfin/Plex use NFS from `192.168.10.100:/mnt/rust/media`
- **Mounted via**: PersistentVolumeClaims in each app

#### Local Storage on k3s3
- **Tiered Storage Classes**:
  - **Ultra Performance**: Intel Optane drives (for databases/high IOPS)
  - **High Performance**: Samsung NVMe drives
  - **Bulk Storage**: SAS SSDs
- **Used by**: Whisparr (using Optane for 30k file database)

#### Temporary Storage
- SABnzbd uses `emptyDir` (local node storage) for incomplete downloads
- Prevents download I/O from hitting NFS
- Automatically cleaned on pod restart
- **Node Affinity**: Pinned to k3s1/k3s2 to prevent I/O contention with primary Longhorn storage on k3s3

## Node Roles and Scheduling

### Node Labels
- **k3s-master1**: Control plane only (tainted with `node-role.kubernetes.io/control-plane:NoSchedule`)
- **k3s1 & k3s2**: 
  - `node-type: compute`
  - `workload: light`
  - `intel-gpu: true`
  - `bgp: enabled`
- **k3s3**:
  - `node-type: gpu`
  - `gpu: nvidia`

### Workload Distribution
- **Control Plane**: k3s-master1 only (no workloads)
- **Light Workloads**: Prefer k3s1/k3s2 (OptiPlexes)
- **GPU Workloads**: k3s3 only (Jellyfin for transcoding)
- **General Media Apps**: Float across all workers
- **Whisparr**: Pinned to k3s3 for Optane storage access

## Deployed Applications

### Media Stack
All apps deployed via Flux GitOps from `/clusters/k3s-home/apps/media/`

- **Sonarr**: TV show management
- **Radarr**: Movie management
- **Lidarr**: Music management
- **Prowlarr**: Indexer management
- **Bazarr**: Subtitle management
- **SABnzbd**: Usenet downloader
- **Jellyfin**: Media server (uses GPU on k3s3)
- **Whisparr**: Adult content management (on k3s3 with Optane storage)
- **Overseerr**: Request management
- **Recyclarr**: Automated trash guide updates

### AI Stack
All apps deployed via Flux GitOps from `/clusters/k3s-home/apps/ai/`

- **Ollama**: LLM inference server (API at ollama.fletcherlabs.net)
  - Running llama3.2:3b model
  - GPU accelerated on Tesla T4
  - 200GB storage for models
- **Open WebUI**: Chat interface for Ollama (ai.fletcherlabs.net)
  - User-friendly web interface for LLM interaction
  - Connects to Ollama backend
- **Automatic1111**: Stable Diffusion WebUI (sd.fletcherlabs.net)
  - Image generation with GPU acceleration
  - 100GB storage for SD models, 50GB for outputs
  - Configured with xformers and medvram optimization

### Infrastructure Components
- **Cilium**: CNI and service mesh
- **NVIDIA Device Plugin**: GPU support for k3s3 with time-slicing
- **Intel GPU Plugin**: QuickSync support for k3s1/k3s2
- **Longhorn**: Distributed block storage with tiered storage classes
- **Velero**: Backup and disaster recovery with MinIO for local S3 storage
- **Authentik**: Identity provider with OAuth2/OIDC support
- **SOPS**: Secrets encryption for GitOps

## Key Operations Performed

### Initial Setup Issues
1. **k3s3 Node Not Ready**
   - Caused by CNI mismatch (K3s expected Flannel, cluster uses Cilium)
   - Fixed by adding `--flannel-backend=none` to k3s-agent

2. **Disk Pressure on Control Plane**
   - Media apps incorrectly scheduled on control plane
   - Only 24GB disk filled up quickly
   - Fixed by removing incorrect `node-type: storage` labels
   - Added proper control plane taint

3. **Gateway Not Accessible**
   - K3s ServiceLB conflicting with Cilium
   - Fixed by disabling ServiceLB in K3s

### Storage Setup on k3s3
```bash
# Formatted and mounted all drives
/mnt/optane-1  - Intel Optane 110GB
/mnt/optane-2  - Intel Optane 110GB  
/mnt/nvme-1    - Samsung 980 PRO 1TB
/mnt/nvme-2    - Samsung 980 PRO 1TB
/mnt/sas-1 through /mnt/sas-7 - 350GB SAS SSDs
```

### NVIDIA GPU Setup
```bash
# Installed on k3s3
- NVIDIA Driver 535
- NVIDIA Container Toolkit
- Containerd configuration for NVIDIA runtime
- NVIDIA Device Plugin for Kubernetes
```

### GPU Time-Slicing Configuration
Enabled GPU sharing between multiple containers:
```yaml
# /clusters/k3s-home/infrastructure/06-nvidia-gpu-plugin/configmap.yaml
sharing:
  timeSlicing:
    resources:
    - name: nvidia.com/gpu
      replicas: 4  # Allow 4 containers to share the GPU
```
This allows Jellyfin, Ollama, and Automatic1111 to share the single Tesla T4.

## Maintenance Notes

### Common Commands
```bash
# Check node status
kubectl get nodes -o wide

# Check pod distribution
kubectl get pods -A -o wide

# Force Flux reconciliation
flux reconcile kustomization apps --with-source

# Check HelmRelease status
kubectl get helmreleases -A

# View Gateway status
kubectl get gateway -n networking main-gateway
```

### Known Issues
1. **HelmReleases may show as failed** even when pods are running (usually reconciles eventually)
2. **Ping to gateway IP fails** - This is normal, HTTP/HTTPS works fine
3. **Journal logs** can fill control plane disk - cleaned with `journalctl --vacuum-time=7d`
4. **Port conflicts** - Multiple services may use same ports internally:
   - SABnzbd: 8080
   - Open WebUI: 8080
   - Automatic1111: Initially tried 8080, fixed to use 7860
5. **PVC spec changes** - Bound PVCs cannot have their spec changed (selector, storage class)
   - Must delete and recreate PVC if changes needed
6. **Flux dependency issues** - Sometimes kustomizations get stuck waiting for dependencies
   - Can manually apply resources while Flux catches up

## Future Considerations

### Potential Improvements
1. **Monitoring Stack**: Prometheus + Grafana for metrics
2. **Additional AI Workloads**: ComfyUI, text-to-speech, or other AI/ML applications
3. **Authentication**: Authelia or Authentik for service protection
4. **Backup Strategy**: Automated config backups for *arr apps
5. **Certificate Management**: cert-manager for automatic TLS
6. **Distributed Storage**: Longhorn or Rook/Ceph to reduce R730 dependency

### Limitations
- No true HA (single storage node)
- Control plane is a single VM
- All storage depends on R730

### Planned Improvements
1. **WSL2 GPU Node**: Add desktop RTX 4090 to cluster via dedicated WSL2 instance
   - See `/home/josh/flux-k3s/docs/wsl2-gpu-node-plan.md` for implementation details
   - Pending 10GbE NIC replacement on desktop
2. **Fix k3s3 Longhorn CSI**: Resolve driver registration issues
3. **Offsite Backups**: Configure Wasabi or B2 for Velero

## Flux GitOps Structure
```
/clusters/k3s-home/
├── apps/
│   └── media/          # Media applications
├── infrastructure/     # Core infrastructure (CNI, CRDs)
├── infrastructure-runtime/  # Runtime configs (storage, priority classes)
└── workloads/         # Cluster sync configuration
```

## Service Access

### Currently Deployed Services
All services accessible via HTTP (no HTTPS/TLS configured yet):

#### Media Stack
- Jellyfin: http://jellyfin.fletcherlabs.net
- Plex: http://plex.fletcherlabs.net
- Sonarr: http://sonarr.fletcherlabs.net
- Radarr: http://radarr.fletcherlabs.net
- Prowlarr: http://prowlarr.fletcherlabs.net
- Whisparr: http://whisparr.fletcherlabs.net
- SABnzbd: http://sabnzbd.fletcherlabs.net

#### AI/ML Stack
- Open WebUI: http://openwebui.fletcherlabs.net
- Automatic1111: http://automatic1111.fletcherlabs.net

#### Infrastructure
- Authentik: http://authentik.fletcherlabs.net (⚠️ DO NOT enable 2FA yet)
- Longhorn: http://longhorn.fletcherlabs.net
- Grafana: http://grafana.fletcherlabs.net (admin / check SOPS secret)

## Quick Troubleshooting

### Service Not Accessible
1. Check if pod is running: `kubectl get pods -n media`
2. Check service endpoints: `kubectl get endpoints -n media`
3. Check gateway status: `kubectl get gateway -n networking`
4. Test via curl: `curl -I http://<service>.fletcherlabs.net`

### Pod Won't Schedule
1. Check node status: `kubectl get nodes`
2. Check pod events: `kubectl describe pod -n <namespace> <pod>`
3. Check for taints: `kubectl describe node <node>`
4. Check resource availability: `kubectl top nodes`

### Disk Space Issues
1. Check disk usage: `df -h`
2. Clean journal logs: `sudo journalctl --vacuum-time=7d`
3. Remove evicted pods: `kubectl delete pod --field-selector status.phase=Failed -A`

### Current Issues Requiring Resolution

1. **k3s3 Longhorn CSI Driver Not Registered**
   - **Symptom**: CSINode k3s3 shows `drivers: null`
   - **Impact**: Pods requiring Longhorn storage can't be scheduled on k3s3
   - **Workaround**: Using local-path storage for monitoring stack
   - **Fix Needed**: Investigate why CSI driver registration fails on k3s3

2. **Monitoring Stack Storage**
   - **Current**: Using local-path due to k3s3 CSI issues
   - **Target**: Should use Longhorn for durability
   - **Action**: Revert to Longhorn storage after fixing CSI driver

3. **Velero Offsite Backup**
   - **Status**: Local MinIO only, no offsite replication
   - **Needed**: Wasabi or B2 configuration for 3-2-1 backup strategy

## Recent Changes (June 13, 2025)

### Morning Session
1. **Added AI Stack**:
   - Ollama for LLM inference with llama3.2:3b model
   - Open WebUI for chat interface
   - Automatic1111 for Stable Diffusion image generation
   - All sharing Tesla T4 GPU via time-slicing

2. **Fixed Storage Issues**:
   - Removed incorrect node selectors causing control plane scheduling
   - Fixed PVC spec immutability issues
   - Corrected storage class usage (local-ssd vs non-existent local-nvme)

3. **Resolved Port Conflicts**:
   - Automatic1111 configured to use port 7860 instead of 8080
   - Avoided conflicts with SABnzbd and Open WebUI

### Afternoon Session (AI Team: Claude + o3-mini + Gemini 2.5 Pro)
1. **Completed Week 3 Observability Implementation**:
   - Deployed kube-prometheus-stack with Prometheus, Grafana, Alertmanager
   - Added NVIDIA DCGM exporter for GPU monitoring
   - Deployed Loki for log aggregation
   - Created HTTPRoute for Grafana access
   - Fixed Flux dependency chain blocking apps deployment

2. **Resolved Critical Issues**:
   - Fixed SABnzbd node affinity patch API version (v2beta1 → v2)
   - Added missing Helm repositories (prometheus-community, grafana)
   - Worked around k3s3 Longhorn CSI driver issues with local-path storage

3. **Documentation Updates**:
   - Updated README.md with current cluster state
   - Created week3-observability-summary.md
   - Added WSL2 GPU node integration plan
   - Fixed GPU specification (Tesla T4, not RTX 4090)

## Documentation Index

### Planning & Architecture Documents
All planning and implementation documentation is maintained to ensure continuity across sessions with AI assistants.

#### Architecture & Planning
- **Architectural Review**: `/home/josh/k3s-homelab-architecture-review.md` - Comprehensive review with risk analysis and improvement roadmap
- **Implementation Roadmap**: `/home/josh/k3s-homelab-implementation-roadmap.md` - Detailed week-by-week execution plan with all phases
- **Week 1 Security Summary**: `/home/josh/week1-security-summary.md` - Authentik and SOPS implementation details
- **Authentik Setup Summary**: `/home/josh/authentik-setup-summary.md` - Specific Authentik deployment details
- **Week 2 Storage Summary**: `/home/josh/week2-storage-backup-summary.md` - Longhorn and Velero implementation details
- **Week 3 Observability Summary**: `/home/josh/flux-k3s/docs/week3-observability-summary.md` - Monitoring stack implementation details
- **WSL2 GPU Node Plan**: `/home/josh/flux-k3s/docs/wsl2-gpu-node-plan.md` - RTX 4090 integration via WSL2
- **Next Session Tasks**: `/home/josh/flux-k3s/docs/next-session-tasks.md` - Immediate priorities after NIC replacement
- **WSL2 Setup Script**: `/home/josh/flux-k3s/docs/setup-wsl-k3s-node.ps1` - PowerShell automation for WSL2 node

#### Implementation Roadmap
Based on architectural review, the implementation is divided into phases:

1. **Week 1 (COMPLETED)**: Security & Authentication
   - ✅ Authentik deployment
   - ✅ SOPS secrets encryption
   - ✅ GitOps security hardening

2. **Week 2 (COMPLETED)**: Storage & Backup
   - ✅ Longhorn distributed storage deployment
   - ✅ Tiered storage classes (optane, nvme, sas-ssd)
   - ✅ Velero backup solution with MinIO
   - ✅ SABnzbd node affinity optimization

3. **Week 3 (COMPLETED)**: Observability
   - ✅ kube-prometheus-stack deployment
   - ✅ NVIDIA DCGM exporter for GPU monitoring
   - ✅ Loki for log aggregation
   - ✅ Grafana dashboards and HTTPRoute
   - ⏳ Offsite backup pending configuration
   - ⚠️ Note: Monitoring stack using local-path storage due to k3s3 Longhorn CSI issues

4. **Week 4**: Scheduled Task Review & Consolidation
   - Review all deployed services and optimize configurations
   - Implement missing alert rules
   - Create comprehensive documentation
   - Plan for high availability improvements

5. **Month 2**: High Availability
   - Multi-master control plane with embedded etcd
   - Implement comprehensive backup strategy
   - Network redundancy improvements

### Quick Reference
- **Cluster Access**: SSH to any node with passwordless access
- **GitOps Repo**: https://github.com/sudoflux/flux-k3s
- **Services Domain**: *.fletcherlabs.net
- **Gateway IP**: 192.168.10.224

### Important Security Information
- **SOPS Age Key**: `~/.config/sops/age/keys.txt` (BACKUP THIS!)
- **Encryption Config**: `/.sops.yaml` in repository root
- **Authentik**: https://authentik.fletcherlabs.net (needs initial setup)
  - **⚠️ IMPORTANT**: Do not enable 2FA/forward auth until all infrastructure work is complete
  - Enabling authentication too early will block automation tools and debugging access
  - Complete all AI assistant implementation work before securing services

---

## AI Team Instructions

⚠️ **IMPORTANT**: System was powered down for 10GbE NIC replacement. This is expected.

### Start Here for Next Session
1. **Read This File First**: CLUSTER-SETUP.md for complete cluster overview
2. **Check Immediate Tasks**: `/home/josh/flux-k3s/docs/next-session-tasks.md`
3. **Current Issues**: See "Current Issues Requiring Resolution" section above
4. **Planned Work**: See "Planned Improvements" section above

### Key Documentation Locations
- **In Repository**: `/home/josh/flux-k3s/docs/` - All new docs are here
- **External Docs**: Listed in "Documentation Index" section above
- **Today's Work**: See "Recent Changes (June 13, 2025)" section

---
Last Updated: June 13, 2025 (Afternoon Session)
Cluster Version: K3s v1.32.5+k3s1