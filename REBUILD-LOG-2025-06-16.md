# K3s Cluster Complete Rebuild Log - June 16, 2025

## Mission
Complete teardown and rebuild of K3s cluster with production-grade architecture.

## Architecture Decisions
- **Platform**: K3s (not full K8s) - production-grade but resource efficient
- **Topology**: 3-node HA cluster (converting all nodes to control-plane)
- **Storage**: Local-path for configs, NFS for media data
- **GitOps**: Flux from the beginning
- **No Longhorn**: Avoiding distributed storage complexity

## Current Status: Starting Teardown

### Phase 1: Document Current State
- Gathering node information
- Backing up any remaining configs
- Documenting network setup

### Node Inventory
- k3s-master1: 192.168.10.30 (current master)
- k3s1: 192.168.10.21 (will become master)
- k3s2: 192.168.10.23 (will become master) 
- k3s3: 192.168.10.31 (will be removed - too many disks, complexity)

### Next Steps
1. Backup flux configs
2. Document network settings
3. Begin node cleanup