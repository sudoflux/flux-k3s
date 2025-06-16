# K3s Cluster Complete Rebuild Log - June 16, 2025

## Mission
Complete teardown and rebuild of K3s cluster with production-grade architecture.

## Architecture Decisions
- **Platform**: K3s (not full K8s) - production-grade but resource efficient
- **Topology**: 3-node HA cluster (all nodes as control-plane)
- **Storage**: Local-path for configs, NFS for media data
- **GitOps**: Flux from the beginning
- **No Longhorn**: Avoiding distributed storage complexity

## Phase 1: Backup Critical Data (COMPLETED)
- ✅ SOPS age key backed up to /tmp/age.key
- ✅ Git repository already contains all manifests
- ✅ Node IPs documented:
  - k3s-master1: 192.168.10.30
  - k3s1: 192.168.10.21
  - k3s2: 192.168.10.23
  - k3s3: 192.168.10.31

## Phase 2: Teardown (COMPLETED)
### Worker Nodes Removal
- ✅ k3s3 deleted from cluster, uninstall complete, SSH down
- ✅ k3s2 deleted from cluster, uninstall running, SSH down (node pingable)
- ✅ k3s1 deleted from cluster, uninstall running, node offline
- ✅ Master node cleaned successfully

### Current Node Status
- **k3s-master1**: ✅ Clean, accessible, ready for fresh install
- **k3s1**: ❌ Offline/unreachable (no route to host)
- **k3s2**: ⚠️ Online but SSH down (connection refused)
- **k3s3**: ❌ Excluded from new cluster

### Repository Updates
- ✅ Removed Longhorn completely from deployments
- ✅ Updated monitoring dependencies
- ✅ Created installation scripts

## Phase 3: Rebuild (STARTING)

### Adjusted Plan
Given that k3s1 and k3s2 are having issues, we'll:
1. Start with single-node K3s on master1
2. Add k3s1 and k3s2 when they're recovered
3. Proceed with Flux deployment immediately

### Installation Scripts Created
- `/scripts/rebuild-cluster.sh` - K3s HA installation
- `/scripts/deploy-cilium.sh` - Cilium CNI deployment
- `/scripts/bootstrap-flux.sh` - Flux GitOps bootstrap

## Phase 3: Rebuild (COMPLETED)

### K3s Installation
- ✅ K3s v1.32.5+k3s1 installed on k3s-master1
- ✅ Single-node cluster initialized with embedded etcd
- ✅ Local-path storage provisioner active

### Flux GitOps Bootstrap  
- ✅ Flux v2.6.1 controllers deployed
- ✅ Git repository credentials configured
- ✅ SOPS age key restored for secrets decryption

### Infrastructure Deployment Progress
- ✅ cluster-sources: All Helm repositories configured
- ✅ infra-crds: Base CRDs installed
- ✅ infra-cert-manager: cert-manager v1.16.2 running
- ✅ infra-cilium: Cilium CNI deploying
- 🔄 infra-nfd: Node Feature Discovery installing
- ⏳ infra-intel-gpu: Waiting for NFD
- ⏳ infra-nvidia-gpu: Waiting for NFD
- ⏳ infra-runtime: Waiting for GPU operators
- ⏳ gpu-management: Waiting for NVIDIA GPU operator
- ⏳ apps: Waiting for runtime infrastructure

## Phase 4: Application Deployment (IN PROGRESS)

### Infrastructure Status
- ✅ All core infrastructure deployed
- ✅ cert-manager, Cilium CNI, NFD all operational
- ✅ Intel and NVIDIA GPU operators installed
- ✅ Local storage classes configured

### Application Deployment
- ✅ Namespaces created: ai, media, monitoring
- 🔄 Media apps deploying (Bazarr starting)
- ⚠️ Longhorn kustomizations failing (expected - Longhorn removed)
- ⚠️ Velero failing (CRDs not installed yet)

### Issues to Address
1. **Longhorn References**: Need to remove Longhorn dependencies from:
   - monitoring kustomization (depends on longhorn)
   - Any PVCs expecting Longhorn storage class

2. **Missing Nodes**: k3s1 and k3s2 still offline
   - Need to be brought back online for HA cluster
   - Will be added as control plane nodes when available

## Current Status: Cluster operational, applications deploying via Flux