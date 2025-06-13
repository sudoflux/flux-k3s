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

### Infrastructure Components
- **Cilium**: CNI and service mesh
- **NVIDIA Device Plugin**: GPU support for k3s3
- **Intel GPU Plugin**: QuickSync support for k3s1/k3s2

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

## Future Considerations

### Potential Improvements
1. **Monitoring Stack**: Prometheus + Grafana for metrics
2. **GPU Workloads**: Ollama, ComfyUI, or other AI/ML applications
3. **Authentication**: Authelia or Authentik for service protection
4. **Backup Strategy**: Automated config backups for *arr apps
5. **Certificate Management**: cert-manager for automatic TLS

### Limitations
- No true HA (single storage node)
- Control plane is a single VM
- All storage depends on R730

## Flux GitOps Structure
```
/clusters/k3s-home/
├── apps/
│   └── media/          # Media applications
├── infrastructure/     # Core infrastructure (CNI, CRDs)
├── infrastructure-runtime/  # Runtime configs (storage, priority classes)
└── workloads/         # Cluster sync configuration
```

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

---
Last Updated: June 2025
Cluster Version: K3s v1.32.5+k3s1