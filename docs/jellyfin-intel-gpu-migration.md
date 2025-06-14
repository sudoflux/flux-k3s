# Jellyfin Intel GPU Migration Summary

## Overview
Successfully migrated Jellyfin from NVIDIA Tesla T4 to Intel QuickSync GPU for video transcoding.

## Migration Details

### Before
- **Node**: k3s3
- **GPU**: NVIDIA Tesla T4 (1 of 4 time-sliced GPUs)
- **Issue**: Occupying valuable AI GPU resources

### After
- **Node**: k3s1
- **GPU**: Intel QuickSync (gpu.intel.com/i915)
- **Benefit**: Tesla T4 now available for AI workloads

## Technical Implementation

### 1. Intel GPU Plugin Setup
- Deployed Intel Device Plugins Operator
- Created GpuDevicePlugin CR (not direct HelmRelease)
- Plugin DaemonSet runs on nodes with `intel.feature.node.kubernetes.io/gpu=true`

### 2. Jellyfin Configuration Changes
```yaml
# Changed nodeSelector
nodeSelector:
  intel.feature.node.kubernetes.io/gpu: "true"

# Changed GPU resources
resources:
  requests:
    gpu.intel.com/i915: "1"
  limits:
    gpu.intel.com/i915: "1"

# Added Intel GPU mounts
persistence:
  dri:
    hostPath: /dev/dri
```

## Benefits
1. **Better Resource Utilization**: AI workloads get dedicated Tesla T4 access
2. **Power Efficiency**: Intel QuickSync is more power-efficient for transcoding
3. **Flexibility**: Can now run more AI workloads simultaneously

## Verification
```bash
# Check Jellyfin is on Intel GPU node
kubectl get pods -n media -l app.kubernetes.io/name=jellyfin -o wide

# Verify Intel GPU usage
kubectl describe pod -n media jellyfin-<pod-id> | grep gpu.intel

# Check Tesla T4 availability
kubectl describe node k3s3 | grep -A 5 "nvidia.com/gpu"
```

## Lessons Learned
1. Intel Device Plugins use operator pattern - don't deploy plugin directly
2. Use NFD labels for nodeSelector, not custom labels
3. GPU sharing via `sharedDevNum` allows multiple containers to use Intel GPU

---
*Migration completed: June 14, 2025*
*Reviewed by: Gemini 2.5 Pro*