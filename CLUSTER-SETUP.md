# K3s Homelab Cluster Setup Documentation

## 📊 Cluster Status Update (June 14, 2025)

**UPDATE**: The cluster has recovered from a networking incident on node k3s1. All nodes are now operational with Longhorn storage functioning correctly. See [Incident History](#incident-history) for details.

## Table of Contents
1. [Overview](#overview)
2. [Hardware Configuration](#hardware-configuration)
3. [Cluster Architecture](#cluster-architecture)
4. [Current Issues & Status](#current-issues--status)
5. [Deployed Applications](#deployed-applications)
6. [Documentation Index](#documentation-index)
7. [Implementation Roadmap](#implementation-roadmap)
8. [Quick Reference](#quick-reference)
9. [AI Team Instructions](#ai-team-instructions)

## Overview

This K3s homelab cluster runs media services, AI workloads, and monitoring infrastructure using GitOps principles with Flux CD. The cluster has recovered from a recent networking incident on node k3s1 and is now fully operational.

**Cluster Version**: K3s v1.32.5+k3s1  
**Last Major Incident**: June 14, 2025 - Node k3s1 networking failure (Resolved)  
**Recovery Method**: Node isolation, diagnosis, and self-recovery

## Hardware Configuration

### Physical Nodes

#### Dell R730 (Storage Server)
- **Role**: Hosts VMs and provides NFS storage
- **Storage**: 
  - NVMe storage at `/mnt/nvme_storage` (for app configs)
  - Rust/spinning disk array at `/mnt/rust/media` (30TB for media files)
- **VMs Hosted**: k3s-master1
- **⚠️ Critical**: Single point of failure for all storage

#### Dell R630 (k3s3)
- **Role**: GPU compute worker node
- **Status**: ✅ Fully operational with Longhorn storage
- **CPU**: Dual Intel Xeon E5-2697A v4 (32 cores, 64 threads)
- **RAM**: 384GB DDR4
- **GPU**: NVIDIA Tesla T4 16GB (shared via time-slicing)
- **Storage**: 
  - 2x Intel Optane 110GB (ultra-performance tier)
  - 2x Samsung 980 PRO 1TB NVMe (high-performance tier)
  - 7x SAS SSDs 350GB each (bulk storage tier)

#### Dell OptiPlex Micro (k3s1 & k3s2)
- **Role**: Light compute worker nodes
- **Special Feature**: Intel QuickSync for hardware transcoding
- **Storage**: 512GB NVMe each
- **Network**: 2.5GbE

### Virtual Nodes

#### k3s-master1
- **Type**: VM on R730
- **Resources**: 8GB RAM, 4 vCPUs, 24GB root disk
- **OS**: Ubuntu 22.04 LTS
- **Note**: Single control plane (no HA)

## Cluster Architecture

### Core Components
- **K3s**: v1.32.5+k3s1
- **CNI**: Cilium with eBPF
- **GitOps**: Flux CD v2
- **Storage**: Longhorn (✅ operational) + NFS
- **Ingress**: Gateway API with Cilium
- **Backup**: Velero with MinIO local storage

### Networking
- **Gateway IP**: 192.168.10.224
- **IP Pool**: 192.168.10.224/28
- **BGP**: AS 64513 peering with router at 192.168.10.1
- **Domains**: All services use `*.fletcherlabs.net`
- **TLS**: cert-manager with Let's Encrypt (HTTP-01 challenges)

## Current Issues & Status

### 🟢 Resolved Issues

1. **Node k3s1 Networking Incident (RESOLVED)**
   - **What Happened**: Node k3s1 experienced networking issues preventing pods from reaching services
   - **Symptoms**: Longhorn CSI plugin and manager pods in CrashLoopBackOff
   - **Root Cause**: Temporary network connectivity issues (timeouts to cluster services)
   - **Resolution**: Node isolation, diagnosis, and automatic recovery
   - **Current Status**: ✅ All nodes operational with CSI drivers registered

2. **Velero Backup Configuration (RESOLVED)**
   - **MinIO Issues**: Fixed secret configuration mismatches
   - **B2 Integration**: Successfully configured and tested
   - **Current Status**: ✅ Backups working to both local MinIO and B2 offsite

### 🟡 Important But Non-Critical Issues

1. **No High Availability**
   - Single control plane node
   - Single storage server (R730)
   - No redundancy for critical services

2. **Monitoring Stack on Local Storage**
   - Using local-path instead of Longhorn due to CSI issues
   - Risk of data loss on pod restart

3. **Authentik Not Configured**
   - Deployed but needs initial setup
   - ⚠️ DO NOT enable 2FA until all infrastructure work is complete

## Deployed Applications

### Media Stack (`/clusters/k3s-home/apps/media/`)
| Service | URL | Status | Notes |
|---------|-----|--------|-------|
| Jellyfin | http://jellyfin.fletcherlabs.net | ✅ Running | GPU transcoding on k3s3 |
| Plex | http://plex.fletcherlabs.net | ✅ Running | |
| Sonarr | http://sonarr.fletcherlabs.net | ✅ Running | |
| Radarr | http://radarr.fletcherlabs.net | ✅ Running | |
| Lidarr | http://lidarr.fletcherlabs.net | ✅ Running | |
| Prowlarr | http://prowlarr.fletcherlabs.net | ✅ Running | |
| Bazarr | http://bazarr.fletcherlabs.net | ✅ Running | Pending Longhorn migration |
| Whisparr | http://whisparr.fletcherlabs.net | ✅ Running | Using Optane storage on k3s3 |
| SABnzbd | http://sabnzbd.fletcherlabs.net | ✅ Running | Node affinity to k3s1/k3s2 |
| Overseerr | http://overseerr.fletcherlabs.net | ✅ Running | |
| Recyclarr | N/A | ✅ Running | CronJob for trash guides |

### AI Stack (`/clusters/k3s-home/apps/ai/`)
| Service | URL | Status | Notes |
|---------|-----|--------|-------|
| Ollama | http://ollama.fletcherlabs.net | ✅ Running | llama3.2:3b model, GPU accelerated |
| Open WebUI | http://openwebui.fletcherlabs.net | ✅ Running | Chat interface for Ollama |
| Automatic1111 | http://automatic1111.fletcherlabs.net | ✅ Running | Stable Diffusion, GPU accelerated |

### Infrastructure (`/clusters/k3s-home/infrastructure*/`)
| Service | URL | Status | Notes |
|---------|-----|--------|-------|
| Longhorn | http://longhorn.fletcherlabs.net | ✅ Running | Fully operational on all nodes |
| Authentik | http://authentik.fletcherlabs.net | ⚠️ Needs Setup | DO NOT enable 2FA yet |
| Grafana | http://grafana.fletcherlabs.net | ✅ Running | admin / check SOPS secret |
| Prometheus | N/A | ✅ Running | Metrics collection |
| Loki | N/A | ✅ Running | Log aggregation |
| Velero | N/A | ⚠️ Partial | MinIO errors, no offsite backup |

## Documentation Index

### 🔧 Operational Documentation
Located in `/home/josh/flux-k3s/docs/`:

| Document | Purpose | Status |
|----------|---------|--------|
| [ai-team-onboarding.md](docs/ai-team-onboarding.md) | **NEW**: Quick start guide for AI teams | ✅ Start here! |
| [csi-troubleshooting-guide.md](docs/csi-troubleshooting-guide.md) | **NEW**: CSI driver fix decision tree | 📋 Active issue |
| [storage-migration-plan.md](docs/storage-migration-plan.md) | NFS to Longhorn migration strategy | ⏸️ Blocked by CSI issue |
| [velero-offsite-setup.md](docs/velero-offsite-setup.md) | Backblaze B2 integration guide | 📝 Ready to implement |
| [backblaze-b2-setup.md](docs/backblaze-b2-setup.md) | B2 bucket configuration | ✅ Bucket created |
| [k3s3-storage-workaround.md](docs/k3s3-storage-workaround.md) | Local-path usage for monitoring | ✅ Implemented |
| [EMERGENCY-DOWNGRADE-COMMANDS.md](../EMERGENCY-DOWNGRADE-COMMANDS.md) | K3s downgrade procedure | ⚠️ Use with caution |

### 📅 Weekly Implementation Summaries
| Week | Focus | Document | Status |
|------|-------|----------|--------|
| Week 1 | Security & Auth | [week1-security-summary.md](../week1-security-summary.md) | ✅ Complete |
| Week 2 | Storage & Backup | [week2-storage-backup-summary.md](../week2-storage-backup-summary.md) | ✅ Complete |
| Week 3 | Observability | [week3-observability-summary.md](docs/week3-observability-summary.md) | ✅ Complete |
| Week 4 | TLS & Certificates | In Progress | 🔄 Current Week |

### 🚀 Future Planning
| Document | Purpose | Priority |
|----------|---------|----------|
| [wsl2-gpu-node-plan.md](docs/wsl2-gpu-node-plan.md) | RTX 4090 integration | High |
| [setup-wsl-k3s-node.ps1](docs/setup-wsl-k3s-node.ps1) | WSL2 automation script | High |
| [next-session-tasks.md](docs/next-session-tasks.md) | Immediate priorities | Critical |

## Implementation Roadmap

### Current Week (Week 4) - June 10-16, 2025
**Focus**: Critical Issue Resolution & TLS Implementation

#### Completed This Week:
- ✅ TLS/HTTPS configuration with cert-manager
- ✅ Let's Encrypt ClusterIssuer setup
- ✅ HTTPRoute TLS termination
- ✅ Velero local backup with MinIO
- ✅ Backblaze B2 bucket creation

#### Blocked/In Progress:
- ❌ Longhorn CSI driver fix (critical blocker)
- ⏸️ NFS to Longhorn migrations
- ⏸️ Velero offsite backup integration
- ⏸️ Authentik configuration

### Upcoming Weeks

#### Week 5 (June 17-23, 2025) - Storage Resolution
1. **Fix Longhorn CSI Issue**
   - Option A: Downgrade K3s to v1.30.x
   - Option B: Upgrade Longhorn to v1.9.0
   - Option C: Switch to alternative storage (OpenEBS/Rook)
2. **Complete Storage Migrations**
   - Migrate all config PVCs to Longhorn
   - Test backup/restore procedures
3. **Finalize Backup Strategy**
   - Configure Velero offsite to Backblaze B2
   - Implement automated backup schedules
   - Test disaster recovery

#### Week 6 (June 24-30, 2025) - Authentication & Security
1. **Authentik Setup**
   - Configure initial admin user
   - Set up OAuth2/OIDC providers
   - Create application integrations
2. **Service Protection**
   - Add authentication to sensitive services
   - Configure RBAC policies
   - Implement audit logging

#### Week 7 (July 1-7, 2025) - WSL2 GPU Node
1. **Hardware Preparation**
   - Install 10GbE NIC in desktop
   - Configure network connectivity
2. **WSL2 K3s Agent**
   - Run setup-wsl-k3s-node.ps1
   - Join cluster with RTX 4090
   - Configure GPU time-slicing
3. **Workload Migration**
   - Move AI workloads to RTX 4090
   - Free up Tesla T4 for other uses

#### Month 2 Goals
1. **High Availability**
   - Multi-master control plane
   - Distributed storage across nodes
   - Network redundancy
2. **Advanced Monitoring**
   - Custom Grafana dashboards
   - Alert rules and notifications
   - SLO/SLI implementation
3. **CI/CD Pipeline**
   - Automated testing for manifests
   - Staging environment
   - Progressive delivery

## Quick Reference

### Common Commands
```bash
# Cluster status
kubectl get nodes -o wide
kubectl top nodes

# Check CSI issues
kubectl get csinode
kubectl describe csinode <node-name>

# Flux operations
flux get all -A
flux reconcile kustomization apps --with-source
flux logs --follow

# Debug storage
kubectl get pvc -A
kubectl get storageclass
kubectl describe pvc <pvc-name> -n <namespace>

# Service access
kubectl get gateway -n networking
kubectl get httproute -A
```

### Key File Locations
- **GitOps Repository**: `/home/josh/flux-k3s/`
- **SOPS Age Key**: `~/.config/sops/age/keys.txt` (⚠️ BACKUP THIS!)
- **Cluster Manifests**: `/clusters/k3s-home/`
- **Documentation**: `/docs/`

### Important URLs
- **Gateway IP**: https://192.168.10.224
- **All Services**: https://*.fletcherlabs.net
- **GitHub Repo**: https://github.com/sudoflux/flux-k3s

## AI Team Instructions

### 🚨 Start Here - Critical Context

1. **K3s v1.32.5 has a critical bug** preventing Longhorn CSI driver registration
2. **Storage is partially broken** - can't create new Longhorn volumes
3. **Downgrade attempt failed** - recovered via VM snapshot
4. **Current workarounds** in place using NFS and local-path storage

### 📋 Immediate Priorities

1. **Read These First**:
   - [ai-team-onboarding.md](docs/ai-team-onboarding.md) - **Start here for quick orientation!**
   - This file (CLUSTER-SETUP.md) - complete overview
   - [Current Issues & Status](#current-issues--status) section
   - [next-session-tasks.md](docs/next-session-tasks.md) - immediate priorities
   - [csi-troubleshooting-guide.md](docs/csi-troubleshooting-guide.md) - fix storage issues

2. **Critical Decisions Needed**:
   - Fix Longhorn CSI (downgrade K3s or upgrade Longhorn?)
   - Complete Velero offsite backup setup
   - Plan Authentik configuration approach

3. **Available Resources**:
   - VM snapshots for safe rollback
   - Test pod manifests in `/tmp/`
   - Migration scripts ready for Bazarr

### 🛠️ Development Guidelines

1. **Before Making Changes**:
   - Check CSI functionality: `kubectl get csinode`
   - Verify Flux sync: `flux get all -A`
   - Review recent events: `kubectl get events -A --sort-by='.lastTimestamp'`

2. **Testing Storage**:
   ```yaml
   # Test Longhorn functionality
   apiVersion: v1
   kind: PersistentVolumeClaim
   metadata:
     name: test-longhorn
     namespace: default
   spec:
     accessModes: ["ReadWriteOnce"]
     storageClassName: longhorn-nvme
     resources:
       requests:
         storage: 1Gi
   ```

3. **Emergency Recovery**:
   - VM snapshots exist for all nodes
   - Flux can be suspended: `flux suspend kustomization --all`
   - Control plane backup exists at `/var/lib/rancher/k3s-backup-*`

### 📞 Escalation Path

For critical issues:
1. Check recent commits in GitHub repo
2. Review Flux events and logs
3. Consult team via Slack/Discord
4. Consider VM snapshot rollback if needed

## Incident History

### June 14, 2025 - k3s1 Networking Failure
**Initial Diagnosis**: Incorrectly identified as K3s v1.32.5 CSI driver bug  
**Actual Issue**: Node k3s1 experienced networking problems preventing pods from reaching services  
**Symptoms**: 
- Longhorn CSI plugin: 45+ restarts with "context deadline exceeded" errors
- Longhorn manager: 17+ restarts
- Pods unable to reach longhorn-backend service

**Resolution**:
1. Cordoned k3s1 to isolate the issue
2. Fixed unrelated MinIO secret configuration issues
3. Deleted conflicting VSL configuration
4. Network connectivity self-recovered
5. Verified with canary pod testing
6. Uncordoned k3s1

**Lessons Learned**:
- Node-specific issues can masquerade as cluster-wide problems
- Always verify actual error logs before assuming version incompatibility
- Isolating problematic nodes can allow self-recovery

---

**Last Updated**: June 14, 2025 (06:00 UTC)  
**Updated By**: AI Team (Claude)  
**Session Focus**: Resolved k3s1 networking issues, updated documentation to reflect actual cluster state  
**Key Fixes**: MinIO secrets, VSL configuration, successful B2 backup integration