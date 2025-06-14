# ADR-003: Intel GPU Plugin for QuickSync Support

## Status
Accepted

## Context
On June 14, 2025, the Intel GPU plugin was mistakenly removed during troubleshooting of Flux reconciliation failures. This was an error as Intel QuickSync hardware acceleration is needed for efficient video transcoding on k3s1 and k3s2 nodes.

## Decision
Restore and properly configure the Intel GPU plugin to enable QuickSync support on OptiPlex nodes.

### Configuration Details
1. **Nodes with Intel GPU**: k3s1 and k3s2 (OptiPlex systems)
2. **Primary Use Case**: QuickSync hardware-accelerated video transcoding
3. **Applications**: Jellyfin (and potentially Plex) can utilize Intel QuickSync

### Technical Implementation
- Added required CRD (GpuDevicePlugin) that was missing
- Maintained node labels: `intel-gpu=true` on k3s1 and k3s2
- Plugin exposes GPU resources only on nodes with Intel GPUs detected

## Consequences

### Positive
- Enables efficient hardware-accelerated transcoding via QuickSync
- Provides scheduling flexibility for media workloads
- Reduces CPU usage for video transcoding tasks
- Allows Jellyfin to run on either NVIDIA or Intel GPU nodes

### Negative
- Additional cluster component to maintain
- Requires CRD management

### Neutral
- Currently Jellyfin uses NVIDIA GPU on k3s3, but can be migrated if needed

## Lessons Learned
1. Always verify hardware utilization before removing infrastructure components
2. QuickSync is valuable for transcoding even when NVIDIA GPUs are available
3. Missing CRDs should be added rather than removing the entire component

---
*Date: June 14, 2025*
*Authors: AI DevOps Team*