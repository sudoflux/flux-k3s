# K3s Homelab Cluster Setup Documentation

## 📊 Cluster Health Status

**Status**: ✅ Fully Operational  
**Last Update**: June 16, 2025 (03:30 UTC)  
**Last Incident**: Prometheus security exposure (resolved) - OAuth2 authentication implemented  
**Current Focus**: Complete OAuth2 setup for remaining services (Longhorn, Grafana)

### ✅ Security Issue Resolved - June 16, 2025
**RESOLVED**: Prometheus now secured with OAuth2 authentication via Authentik  
**Status**: OAuth2-Proxy successfully deployed and protecting all access  
**Next Steps**: Apply same security model to Longhorn UI - see [LONGHORN-OAUTH2-SETUP.md](LONGHORN-OAUTH2-SETUP.md)

### Previous Incident - June 15, 2025
**Major Incident Resolved**: 24-hour Longhorn outage due to kubelet path changes  
**Resolution**: Complete removal and fresh installation of Longhorn v1.6.2  
**Essential Reading**:
- [LONGHORN-INCIDENT-POSTMORTEM-2025-06-15.md](docs/LONGHORN-INCIDENT-POSTMORTEM-2025-06-15.md)
- [NEXT-STEPS-AFTER-LONGHORN-2025-06-15.md](docs/NEXT-STEPS-AFTER-LONGHORN-2025-06-15.md)

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
**Last Major Incident**: June 15, 2025 - Longhorn CSI complete failure (Resolved)  
**Recovery Method**: Nuclear cleanup and fresh installation  
**Data Loss**: Complete - all Longhorn volumes lost

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

### ✅ Recently Completed (June 15-16, 2025)

#### Day Shift Accomplishments
1. **Monitoring Stack Storage** ✅
   - **Resolved**: Migrated from ephemeral to persistent storage
   - **Note**: Using local-path for Prometheus/Alertmanager due to Longhorn fsGroup issues
   - **Grafana**: Successfully using Longhorn storage
   
2. **Backup Strategy** ✅
   - **Resolved**: Velero configured with Backblaze B2
   - **Schedules**: Hourly (Longhorn), Daily (critical), Weekly (full cluster)
   - **Tested**: Backup and restore verified working
   
3. **SOPS Encryption** ✅
   - **Status**: Already properly configured and working
   - **All secrets**: Encrypted with age keys
   
4. **Authentik Deployment** ✅
   - **Status**: Deployed and accessible at https://authentik.fletcherlabs.net
   - **Next**: Initial admin setup required (NO 2FA per directive)

#### Evening Shift Accomplishments
5. **Monitoring Alerts** ✅
   - **Added**: Comprehensive Longhorn health alerts
   - **Coverage**: Volume health, node storage, disk capacity, CSI status
   - **Templates**: Alert message templates configured
   
6. **Prometheus External Access & OAuth2-Proxy Deployment** ✅
   - **Status**: Accessible at https://prometheus.fletcherlabs.net
   - **OAuth2-Proxy**: Deployed and configured for Prometheus, awaiting Authentik integration
   - **Security**: ⚠️ NO AUTHENTICATION YET - critical priority to complete setup
   - **HTTPRoute**: Ready to be updated once Authentik is configured
   
7. **Traefik Disable Instructions** ✅
   - **Documentation**: Complete guide to permanently disable K3s Traefik
   - **Scripts**: Ready in `/home/josh/flux-k3s/scripts/`
   - **Status**: Not yet executed (requires master node access)
   
8. **OAuth2 Templates** ✅
   - **Created**: Complete OAuth2-Proxy configurations
   - **Ready for**: Longhorn, Grafana, Prometheus integration
   - **Location**: `docs/oauth2-integration-templates.md`

#### Night Shift Accomplishments
9. **OAuth2-Proxy Deployment for Prometheus** ✅
   - **Status**: Successfully deployed and running
   - **Configuration**: OIDC provider pointing to Authentik
   - **Issues Fixed**: Helm chart compatibility, cookie secret length, OIDC URL format
   - **Next Step**: Complete Authentik setup to enable authentication
   
10. **Security Documentation** ✅
    - **Created**: Step-by-step Authentik setup guide
    - **Location**: `docs/authentik-prometheus-setup-guide.md`
    - **Status Report**: `docs/oauth2-proxy-status-2025-06-15.md`

#### Early Morning Shift Accomplishments (June 16)
11. **OAuth2-Proxy DNS Resolution Fixed** ✅
    - **Problem**: Pods couldn't resolve authentik.fletcherlabs.net internally
    - **Solution**: Added hostAlias to map domain to gateway IP (192.168.10.224)
    - **Status**: OAuth2-Proxy now reaching Authentik, getting expected 404
    - **Docs**: `docs/oauth2-proxy-dns-fix-status.md`
    
12. **Critical Security Documentation** ✅
    - **Created**: Urgent action guide for securing Prometheus
    - **Location**: `CURRENT-CRITICAL-STATUS.md`
    - **Contains**: Step-by-step instructions with exact commands

### ✅ Critical Security Issue Resolved (June 16, 2025 Early Morning)
13. **Prometheus OAuth2 Authentication** ✅
    - **Problem**: Prometheus was exposed without authentication
    - **Solution**: Deployed OAuth2-Proxy with Authentik integration
    - **Key Fixes**: OIDC issuer URL trailing slash, DNS hostAlias
    - **Result**: All access now requires Authentik authentication
    
14. **OAuth2 Automation Created** ✅
    - **Script**: `scripts/deploy-oauth2-service.sh`
    - **Purpose**: Automates OAuth2-Proxy deployment for any service
    - **Benefit**: Reduces 30-45 minute process to 5-10 minutes
    
15. **Longhorn OAuth2 Prepared** ✅
    - **Status**: All manifests created and committed
    - **Guide**: `LONGHORN-OAUTH2-SETUP.md` (5-minute setup)
    - **Pending**: Only needs Authentik configuration

### Day Shift Accomplishments (June 16, 2025)
16. **Intel GPU Plugin Fixed** ✅
    - **Problem**: Plugin only worked on k3s1, failed on k3s2
    - **Root Cause**: Legacy kubelet directories from Longhorn incident
    - **Resolution**: Fixed permissions and paths, now working on both nodes
    - **GPU Resources**: 10 Intel GPU on k3s1, 10 on k3s2, 4 NVIDIA on k3s3
    
17. **Media Services Recovered** ✅
    - **Issue**: All media PVCs stuck due to "Released" PVs
    - **Fixed**: Cleared claimRef on all PVs, updated wrong PVC references
    - **Result**: All media services now running
    
18. **Cluster Cleanup** ✅
    - **Removed**: 36 orphaned node-debugger pods
    - **Deleted**: Old k3s-feature-fix ConfigMap from Longhorn incident
    - **Fixed**: Multiple stuck pods and failed jobs
    - **Documented**: All technical debt and workarounds
    
19. **Longhorn fsGroup Bug Identified** 🔴
    - **Discovery**: Monitoring stack can't use Longhorn due to v1.6.2 bug
    - **Research**: ChatGPT o4 mini provided detailed analysis
    - **Solution**: Requires upgrade to Longhorn v1.9.x
    - **Current State**: Grafana scaled to 0, monitoring on local-path

### 🟡 Active Work Items

#### Priority 1 - Critical SPOFs
1. **Storage Single Point of Failure** 🔴
   - **Status**: R730 hosts all NFS storage
   - **Risk**: Hardware failure = 30TB data loss
   - **Options**: GlusterFS, SeaweedFS, or secondary NFS

2. **No Control Plane HA** 🔴
   - **Status**: Single k3s-master1 VM
   - **Risk**: VM failure = no cluster management
   - **Solution**: Deploy 3 masters with embedded etcd

#### Priority 2 - Broken Services
3. **DCGM Exporter** ✅
   - **Status**: Running - Successfully deployed and collecting metrics
   - **Resolution**: Large image pull completed after ~15 minutes
   - **Actions Taken**:
     - Updated health probes with longer initial delays (60s liveness, 45s readiness)
     - Added required volume mounts (nvidia-install-dir-host, device-metrics)
     - Updated to compatible image version (3.3.5-3.4.0-ubuntu22.04)
     - Restored privileged mode temporarily for debugging
   - **Current State**: Fully operational, exposing GPU metrics on port 9400
   - **Metrics Available**: GPU temperature, utilization, memory, power usage

4. **SOPS in Monitoring** 🟠
   - **Status**: Not decrypting secrets
   - **Impact**: OAuth2 secrets in plain text
   - **Workaround**: Manual secret creation

#### Priority 3 - Storage Issues
5. **Longhorn fsGroup Bug** 🔴
   - **Version**: 1.6.2 (current)
   - **Impact**: Pods with fsGroup can't mount Longhorn volumes
   - **Affected**: Prometheus, AlertManager, Grafana
   - **Workaround**: Using local-path storage
   - **Solution**: Upgrade to Longhorn 1.9.x

#### Priority 4 - Technical Debt
6. **DNS Hairpin Resolution** 🟡
   - **Current**: hostAlias workaround in OAuth2 proxies
   - **Solution**: Configure CoreDNS properly

7. **MinIO Local Storage** 🟡
   - **Status**: Broken ("0 drives provided")
   - **Impact**: No local backups (B2 working)

8. **Traefik Noise** 🟢
   - **Status**: K3s trying to install Traefik
   - **Impact**: Log spam only
   - **Fix**: Run disable-traefik.sh

## Deployed Applications

### Media Stack (`/clusters/k3s-home/apps/media/`)
| Service | URL | Status | Notes |
|---------|-----|--------|-------|
| Jellyfin | http://jellyfin.fletcherlabs.net | ✅ Running | GPU transcoding on k3s1 |
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
| Longhorn | https://longhorn.fletcherlabs.net | ✅ Running | v1.6.2 fresh install after incident |
| Authentik | https://authentik.fletcherlabs.net | ✅ Running | Admin configured, OAuth2 providers active |
| Grafana | https://grafana.fletcherlabs.net | ✅ Running | admin / check SOPS secret |
| Prometheus | https://prometheus.fletcherlabs.net | ✅ Running | Secured with OAuth2-Proxy + Authentik |
| Loki | N/A | ✅ Running | Log aggregation working |
| Velero | N/A | ✅ Running | B2 backups configured, MinIO local broken |

## Documentation Index

### 📊 Critical Documentation
| Document | Purpose | Priority |
|----------|---------|----------|
| **[DEPLOYMENT-ANALYSIS.md](DEPLOYMENT-ANALYSIS.md)** | Comprehensive deployment review & roadmap | 🔴 **START HERE** |
| **[NEXT-SESSION-PROMPT.md](NEXT-SESSION-PROMPT.md)** | Current priorities and immediate actions | 🎯 **DAILY GUIDE** |
| **[LONGHORN-INCIDENT-POSTMORTEM-2025-06-15.md](docs/LONGHORN-INCIDENT-POSTMORTEM-2025-06-15.md)** | Major incident analysis | 📚 **LESSONS LEARNED** |

### 🔧 Operational Documentation
Located in `/home/josh/flux-k3s/docs/`:
| [LONGHORN-FIX-SUMMARY-2025-06-15.md](docs/LONGHORN-FIX-SUMMARY-2025-06-15.md) | Quick reference for the fix | ✅ Complete |
| [ai-team-onboarding.md](docs/ai-team-onboarding.md) | Quick start guide for AI teams | ✅ Start here! |
| [csi-troubleshooting-guide.md](docs/csi-troubleshooting-guide.md) | CSI driver fix decision tree | ✅ Issue resolved |
| [storage-migration-plan.md](docs/storage-migration-plan.md) | NFS to Longhorn migration strategy | ✅ Partially complete |
| [velero-offsite-setup.md](docs/velero-offsite-setup.md) | Backblaze B2 integration guide | ✅ **CONFIGURED** |
| [backblaze-b2-setup.md](docs/backblaze-b2-setup.md) | B2 bucket configuration | ✅ Working |
| [k3s3-storage-workaround.md](docs/k3s3-storage-workaround.md) | Local-path usage for monitoring | ✅ Implemented |

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

### ✅ Deployment Plan Progress
See [DEPLOYMENT-ANALYSIS.md](DEPLOYMENT-ANALYSIS.md) for comprehensive review

| Phase | Status | Completion |
|-------|--------|------------|
| Week 1: Security & Backup | ✅ Complete | Authentik, SOPS, Velero all deployed |
| Week 2-3: Storage Resilience | ✅ Complete | Longhorn deployed with tiered storage |
| Week 4: Observability | ⚠️ Partial | Prometheus/Loki working, DCGM broken |
| Month 2: High Availability | ❌ Not Started | Critical SPOFs remain |

### 🔴 Critical Remaining Issues
1. **Storage SPOF**: R730 failure = total data loss
2. **Control Plane SPOF**: Single master VM
3. **GPU Monitoring**: DCGM exporter broken

### Current Week: Week 5 (June 17-23, 2025)
**Focus**: Fix GPU monitoring, test backups, address SPOFs

#### ✅ Completed (June 15-16, 2025)
1. **Critical Infrastructure Recovery**
   - ✅ Monitoring storage migrated (with fsGroup workaround)
   - ✅ Velero backups to B2 configured and tested
   - ✅ SOPS encryption verified working
   - ✅ Authentik deployed (needs config)
   - ✅ Flux reconciliation fixed
   - ✅ Monitoring alerts configured (Longhorn, backup failures)
   - ✅ Prometheus external access (needs auth)
   - ✅ OAuth2 templates prepared
   - ✅ OAuth2-Proxy deployed for Prometheus (awaiting Authentik)

#### Priority 1 - High (This Week)
1. **Authentik Configuration**
   - Create initial admin account
   - Configure OAuth2/OIDC providers
   - Protect critical services (Longhorn, Grafana)
   - Document setup procedures

2. **Monitoring Alerts**
   - Configure Longhorn health alerts
   - Set up CSI driver monitoring
   - Create backup failure notifications
   - Test alert routing

#### Priority 2 - Medium (If Time Permits)
3. **Documentation Updates**
   - Update runbooks with incident learnings
   - Create Longhorn operations guide
   - Document backup/restore procedures
   - Create security configuration guide

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

# Check backups
velero backup get
velero schedule get
velero backup create test-backup --include-namespaces=default

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

# Monitoring access
echo "Grafana: https://grafana.fletcherlabs.net"
echo "Longhorn: https://longhorn.fletcherlabs.net"
echo "Authentik: https://authentik.fletcherlabs.net"
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

### AAR: Longhorn CSI Complete Failure (June 15, 2025)

**1. What Happened:** Longhorn storage system completely failed after kubelet path changes. 24-hour outage with complete data loss.

**2. Timeline:**
- **June 14 AM**: Day shift changed kubelet paths from K3s default to standard
- **June 14 PM**: CSI drivers stopped functioning, volumes inaccessible
- **June 15 Early AM**: Nuclear cleanup approach decided after recovery attempts failed
- **June 15 AM**: Fresh Longhorn v1.6.2 installed with correct paths

**3. Root Cause Analysis:**
- **Direct Cause:** Kubelet path change broke CSI socket connections
- **Contributing Factors:**
  - No documentation of K3s-specific requirements
  - No testing before infrastructure changes
  - Admission webhooks prevented cleanup

**4. What Went Well / What Could Be Improved:**
- ✅ **Well:** Nuclear cleanup script worked perfectly
- ✅ **Well:** Fresh installation restored functionality
- ✅ **Well:** Comprehensive documentation created
- ⚠️ **Improve:** Never change critical paths without full migration plan
- ⚠️ **Improve:** Need better change management process
- ⚠️ **Improve:** Monitoring didn't catch CSI registration failures

**5. Action Items & Lessons Learned:**
- **Action:** Migrate monitoring to Longhorn storage (Priority: P0)
- **Action:** Configure Velero backups immediately (Priority: P0)
- **Action:** Implement SOPS encryption (Priority: P1)
- **Lesson:** K3s uses `/var/lib/rancher/k3s/agent/kubelet` - NEVER change without storage migration
- **Lesson:** Sometimes nuclear cleanup is the right approach
- **Lesson:** Comprehensive documentation prevents repeat incidents

**Full Details:** See [LONGHORN-INCIDENT-POSTMORTEM-2025-06-15.md](docs/LONGHORN-INCIDENT-POSTMORTEM-2025-06-15.md)

### AAR: Monitoring Alerts Implementation (June 15, 2025 - Evening)

**1. What Happened:** Implemented comprehensive monitoring alerts for Longhorn storage system to prevent future incidents like the CSI failure.

**2. Timeline:**
- **Evening**: Created PrometheusRule resources for Longhorn health monitoring
- Configured alert templates for better notification formatting
- Added alerts for volume health, node storage, disk capacity, and CSI status
- Integrated with existing kube-prometheus-stack

**3. What Went Well:**
- ✅ **Well:** Alert rules cover all critical Longhorn metrics
- ✅ **Well:** Proper severity levels (warning/critical) with appropriate thresholds
- ✅ **Well:** Runbook URLs included for quick troubleshooting
- ✅ **Well:** Templates provide clear, actionable alert messages

**4. Action Items:**
- **Action:** Test alert firing with simulated failures (Priority: P2)
- **Action:** Configure alert routing to external channels (Priority: P2)
- **Lesson:** Proactive monitoring prevents catastrophic failures

### AAR: Prometheus External Access Configuration (June 15, 2025 - Evening)

**1. What Happened:** Exposed Prometheus UI externally to enable metric access, but without authentication due to Authentik not being configured yet.

**2. Security Concern:**
- **Issue:** Prometheus contains sensitive system metrics
- **Risk:** Currently accessible without any authentication
- **Mitigation Plan:** OAuth2-Proxy templates ready for immediate deployment

**3. What Went Well:**
- ✅ **Well:** HTTPRoute configuration working correctly
- ✅ **Well:** Security risk documented prominently
- ✅ **Well:** OAuth2 templates prepared for quick implementation

**4. Action Items:**
- **Action:** Configure Authentik IMMEDIATELY (Priority: P0)
- **Action:** Apply OAuth2-Proxy to Prometheus (Priority: P0)
- **Lesson:** Never expose monitoring tools without authentication

### AAR: OAuth2-Proxy Deployment (June 15-16, 2025 - Night)

**1. What Happened:** Deployed OAuth2-Proxy for Prometheus to address the critical security exposure. Encountered multiple technical challenges during deployment.

**2. Timeline:**
- **Night Shift Start**: OAuth2-Proxy Helm repository added
- **Initial Deploy**: Failed due to helm chart value changes (service.port deprecated)
- **Second Issue**: Cookie secret length error (was 167 bytes, needs 32)
- **Third Issue**: SOPS decryption not working in monitoring namespace
- **Fourth Issue**: OIDC issuer URL format incorrect
- **Resolution**: OAuth2-Proxy running, waiting for Authentik config

**3. Technical Issues Resolved:**
- **Helm Values**: Changed `service.port` to `service.portNumber` for v7.7.1
- **Cookie Secret**: Generated proper 32-byte secret for AES cipher
- **SOPS**: Added decryption config but used plain secret as workaround
- **OIDC URL**: Removed trailing slash from issuer URL

**4. What Went Well / What Could Be Improved:**
- ✅ **Well:** Quick iteration and problem-solving
- ✅ **Well:** Comprehensive documentation created
- ✅ **Well:** OAuth2-Proxy successfully deployed
- ⚠️ **Improve:** SOPS should have been configured from the start
- ⚠️ **Improve:** Should have checked helm chart docs for breaking changes

**5. Action Items & Lessons Learned:**
- **Action:** Investigate why SOPS isn't decrypting in monitoring namespace (Priority: P2)
- **Action:** Complete Authentik setup IMMEDIATELY (Priority: P0)
- **Lesson:** Always check helm chart release notes for breaking changes
- **Lesson:** OAuth2-Proxy cookie secret must be exactly 16, 24, or 32 bytes
- **Lesson:** Authentik OIDC issuer URLs don't use trailing slashes

### AAR: OAuth2-Proxy DNS Resolution (June 16, 2025 - Early Morning)

**1. What Happened:** OAuth2-Proxy pods couldn't resolve authentik.fletcherlabs.net from inside the cluster, preventing OIDC discovery and authentication setup.

**2. Timeline:**
- **Detection**: OAuth2-Proxy pods in CrashLoopBackOff with DNS resolution errors
- **Analysis**: Internal pods can't resolve external domains that point back to cluster
- **Solution**: Added hostAlias to OAuth2-Proxy deployment
- **Result**: Pods now reach Authentik, getting expected 404 (provider not configured)

**3. Root Cause Analysis:**
- **Direct Cause:** Classic DNS hairpin/NAT loopback issue
- **Contributing Factor:** Cluster DNS doesn't resolve external domains internally
- **Impact:** Blocked OAuth2-Proxy from performing OIDC discovery

**4. What Went Well / What Could Be Improved:**
- ✅ **Well:** Quick diagnosis and implementation of workaround
- ✅ **Well:** Comprehensive documentation created
- ✅ **Well:** Multiple solution options evaluated
- ⚠️ **Improve:** Should implement proper CoreDNS solution
- ⚠️ **Improve:** This is a common pattern that needs standardization

**5. Action Items & Lessons Learned:**
- **Action:** Implement CoreDNS hairpin resolution (Priority: P2)
- **Action:** Document pattern for other services (Priority: P3)
- **Lesson:** Internal services often can't resolve their own external domains
- **Lesson:** HostAlias is a quick fix, CoreDNS is the proper solution
- **Lesson:** Always test DNS resolution from pod perspective

### AAR: DCGM Exporter Debugging (June 16, 2025)

**1. What Happened:** DCGM exporter pods were stuck in ContainerCreating state on k3s3 node with Tesla T4 GPU.

**2. Timeline:**
- **Initial State**: Pods showing as Running with 10 restarts, failing health checks
- **Investigation**: Other GPU workloads (automatic1111) working fine with nvidia runtime
- **Root Cause**: Combination of missing volume mounts and incompatible image version
- **Resolution**: Updated configuration but final verification pending due to slow image pull

**3. Technical Issues Resolved:**
- **Health Probes**: Configured with appropriate delays for GPU initialization (60s/45s)
- **Volume Mounts**: Added nvidia-install-dir-host and device-metrics mounts
- **Image Version**: Updated to 3.3.5-3.4.0-ubuntu22.04 (compatible with driver 535)
- **Security Context**: Temporarily restored privileged mode for debugging

**4. What Went Well / What Could Be Improved:**
- ✅ **Well:** Systematic debugging approach using team collaboration tools
- ✅ **Well:** Identified compatibility requirements through web search
- ✅ **Well:** Configuration updates properly committed to Git
- ⚠️ **Improve:** Large container images (DCGM) cause extended startup times
- ⚠️ **Improve:** Need local image caching or registry mirror for faster pulls

**5. Action Items & Lessons Learned:**
- **Action:** Monitor pod startup after image pull completes (Owner: Next shift)
- **Action:** Consider pre-pulling GPU monitoring images to nodes (Priority: P3)
- **Lesson:** DCGM requires specific volume mounts not documented in helm chart
- **Lesson:** GPU monitoring tools often have strict driver version dependencies
- **Lesson:** ContainerCreating without events often indicates image pull in progress

---

**Last Updated**: June 16, 2025 (18:00 UTC)  
**Updated By**: AI Team (Claude Opus 4)  
**Next Priority**: Upgrade Longhorn to v1.9.x to fix monitoring storage