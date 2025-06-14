# K3s Homelab Cluster Setup Documentation

## 📊 Cluster Health Status

**Status**: ✅ All Systems Operational  
**Last Update**: June 14, 2025  
**Last Incident**: k3s1 networking failure (resolved) - See [AAR Log](#aar-log) for details

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
- **Storage**: Longhorn v1.6.2 + NFS
  - See [Storage Architecture](#storage-architecture) for tier details
- **Ingress**: Gateway API with Cilium
- **Backup**: Velero with MinIO local storage

### Networking
- **CNI**: Cilium v1.15.6 with eBPF
  - **Mode**: Tunnel (VXLAN) - `routing-mode: tunnel`
  - **Kube-proxy**: Replaced by eBPF (no iptables)
  - **Gateway API**: v1.1.0 with ALPN and app-protocol support enabled
- **Gateway IP**: 192.168.10.224
- **IP Pool**: 192.168.10.224/28
- **BGP**: AS 64512 (cluster) ↔ AS 64513 (router at 192.168.10.1)
- **Domains**: All services use `*.fletcherlabs.net`
- **TLS**: cert-manager with Let's Encrypt (HTTP-01 challenges)
- **Network Links**: All nodes on shared 2.5GbE (potential bottleneck for NFS)

## 🟡 Active Work Items & Known Issues

### Priority 0 - Critical
1. **Flux Reconciliation Failures**
   - Authentik: Missing secret `authentik/authentik-secret`
   - Intel GPU Plugin: CRDs not installed
   - **Impact**: GitOps loop incomplete
   - **Next Steps**: See [next-session-tasks.md](docs/next-session-tasks.md#flux-reconciliation)

### Priority 1 - High
2. **k3s1 Network Failure Root Cause**
   - **Status**: Incident resolved but root cause unknown
   - **Risk**: May recur without understanding underlying issue
   - **Next Steps**: Analyze logs from incident timeframe

3. **Monitoring Stack on Ephemeral Storage**
   - **Current**: Using local-path (non-replicated)
   - **Risk**: Data loss on pod restart/node failure
   - **Next Steps**: Migrate to Longhorn storage classes

### Priority 2 - Medium  
4. **No High Availability**
   - Single control plane node (k3s-master1)
   - Single storage server (R730)
   - **Impact**: No failover capability

5. **Authentik Initial Configuration**
   - **Status**: Deployed but not configured
   - **Note**: DO NOT enable 2FA until all infrastructure work complete

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
| Week 4 | TLS & Gateway API | [week4-tls-gateway-summary.md](docs/week4-tls-gateway-summary.md) | ✅ Complete |

### 🚀 Future Planning
| Document | Purpose | Priority |
|----------|---------|----------|
| [wsl2-gpu-node-plan.md](docs/wsl2-gpu-node-plan.md) | RTX 4090 integration | High |
| [setup-wsl-k3s-node.ps1](docs/setup-wsl-k3s-node.ps1) | WSL2 automation script | High |
| [next-session-tasks.md](docs/next-session-tasks.md) | Immediate priorities | Critical |

## Implementation Roadmap

### Completed: Week 4 (June 10-16, 2025)
**Focus**: TLS Implementation & Incident Response
**Outcome**: All critical issues resolved, HTTPS working, comprehensive documentation updates

See [week4-tls-gateway-summary.md](docs/week4-tls-gateway-summary.md) for details.

### Current Week: Week 5 (June 17-23, 2025)
**Focus**: GitOps Health & System Stability

#### Priority 0 - Critical (Must Fix)
1. **Fix Flux Reconciliation**
   - Resolve Authentik secret issue
   - Install Intel GPU CRDs or remove HelmRelease
   - Restore full GitOps automation

#### Priority 1 - High (This Week)
2. **k3s1 Root Cause Analysis**
   - Analyze logs from incident timeframe
   - Check for resource exhaustion
   - Document findings in AAR format

3. **Monitoring Storage Migration**
   - Backup current data
   - Migrate Prometheus/Grafana/Loki to Longhorn
   - Verify data persistence

#### Priority 2 - Medium (If Time Permits)
4. **Authentik Configuration**
   - Initial setup (no 2FA)
   - Create OAuth2/OIDC providers
   - Document configuration

### Future Weeks

#### Week 6 (June 24-30, 2025) - Security & Authentication
1. **Complete Authentik Setup**
   - Application integrations
   - RBAC policies
   - Audit logging

2. **Security Hardening**
   - Network policies
   - Pod security standards
   - Secret rotation procedures

#### Week 7 (July 1-7, 2025) - High Availability Planning
1. **Multi-Master Research**
   - Requirements documentation
   - Migration strategy
   - Risk assessment

2. **Storage Redundancy**
   - Distributed storage evaluation
   - NFS failover options
   - Backup strategy improvements

#### Week 8 (July 8-14, 2025) - WSL2 GPU Node
*Pending 10GbE NIC installation*
1. **Hardware Setup**
   - Install network card
   - Configure connectivity

2. **WSL2 K3s Agent**
   - Run setup script
   - Join cluster with RTX 4090
   - Migrate AI workloads

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

### SOPS Workflow
1. **Edit encrypted files**: `sops path/to/secret.yaml`
2. **Encrypt new files**: `sops --encrypt --in-place path/to/secret.yaml`
3. **Public key configuration**: Defined in `.sops.yaml` at repo root
4. **Age key location**: `~/.config/sops/age/keys.txt`
5. **Backup reminder**: This key is critical for cluster recovery!

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

## Storage Architecture

### Storage Tiers
| Tier | Technology | Node(s) | Performance | Use Case |
|------|------------|---------|-------------|----------|
| **Replicated Block** | Longhorn | All Workers | High IOPS, Replicated | App configs, databases, critical state |
| | └ longhorn-optane | k3s3 | Ultra-high IOPS | Performance-critical apps |
| | └ longhorn-nvme | k3s3 | High IOPS | General app storage |
| | └ longhorn-sas-ssd | k3s3 | Medium IOPS | Bulk app storage |
| | └ longhorn | k3s1, k3s2 | Standard | Default storage class |
| **Bulk Media** | NFS | R730 | High throughput | Media files (30TB), large datasets |
| **Ephemeral** | local-path | All Workers | Fast, non-replicated | Caches, temp data, monitoring* |

*Monitoring stack currently on local-path, should migrate to Longhorn

### GPU Architecture
| Node | GPU | Mode | Resources | Limitations |
|------|-----|------|-----------|-------------|
| k3s3 | Tesla T4 16GB | Time-slicing | nvidia.com/gpu: 4 | No memory isolation between workloads |
| Desktop* | RTX 4090 24GB | N/A | TBD | Planned addition via WSL2 |

*Requires 10GbE NIC installation first

## AAR Log

### AAR: k3s1 Networking Failure (June 14, 2025)

**1. What Happened:** Node k3s1 lost connectivity to cluster services, causing Longhorn pods to crash repeatedly. Initially misdiagnosed as K3s v1.32.5 CSI driver bug.

**2. Timeline:**
- Detection: Longhorn pods in CrashLoopBackOff with "context deadline exceeded"
- Initial diagnosis: Assumed CSI driver incompatibility
- Investigation: Discovered all nodes had CSI drivers registered
- Root cause found: k3s1 networking issue
- Resolution: Cordoned k3s1, allowed self-recovery, verified with canary pod

**3. Root Cause Analysis:**
- **Direct Cause:** Network service failure on k3s1 (specific trigger unknown)
- **Contributing Factors:** 
  - Lack of node-level network monitoring
  - CSI error messages masked underlying network issue

**4. What Went Well / What Could Be Improved:**
- ✅ **Well:** Node isolation prevented cluster-wide impact
- ✅ **Well:** Discovered and fixed unrelated issues (MinIO secrets, VSL config)
- ⚠️ **Improve:** Started with application layer (CSI) instead of network layer
- ⚠️ **Improve:** No automated alerting for node network health

**5. Action Items & Lessons Learned:**
- **Action:** Investigate k3s1 logs for root cause (Owner: AI Team, Priority: P1)
- **Action:** Create node network health monitoring (Owner: AI Team, Priority: P2)
- **Action:** Update troubleshooting guides to check connectivity first (Owner: AI Team, Complete)
- **Lesson:** Always verify Layer 3/4 connectivity before debugging application protocols
- **Lesson:** Node-specific issues can present as cluster-wide symptoms

### AAR: Gateway HTTPS/TLS Resolution (June 14, 2025)

**1. What Happened:** HTTPS services were inaccessible with connection reset errors. Fixed by enabling ALPN and app-protocol support in Cilium.

**2. Root Cause Analysis:**
- **Direct Cause:** Cilium Gateway API configuration missing required features
- **Contributing Factors:** Gateway API requirements not fully documented

**3. Configuration Changes:**
```yaml
# Required for Gateway API HTTP/2 and gRPC support
enable-gateway-api-alpn: "true"        # Enables ALPN negotiation
enable-gateway-api-app-protocol: "true" # Enables backend protocol selection
```

**4. Lessons Learned:**
- **Lesson:** Gateway API requires specific Cilium features for full functionality
- **Lesson:** ALPN is mandatory for proper HTTP/2 and gRPC support

---

**Last Updated**: June 14, 2025  
**Updated By**: AI Team (Claude)  
**Next Review**: After Week 5 implementation