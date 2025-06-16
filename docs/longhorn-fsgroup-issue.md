# Longhorn fsGroup Issue

## Problem
Longhorn v1.6.2 has a known bug with fsGroup that causes pod mount failures:
```
applyFSGroup failed: lstat .../mount: no such file or directory
```

## Affected Services
- Prometheus - Moved to local-path
- AlertManager - Moved to local-path  
- Grafana - Currently broken

## Root Cause
Longhorn's CSI driver in versions < 1.9.0 has a race condition when Kubernetes tries to apply fsGroup permissions. The kubelet attempts to chmod/chown before the mount point is fully created.

## Solutions

### Option 1: Upgrade Longhorn to 1.9.x
Longhorn 1.9.0+ includes CSI fsGroupPolicy support that fixes this issue.

### Option 2: Use fsGroupChangePolicy (Tried - Failed)
Adding `fsGroupChangePolicy: "OnRootMismatch"` should help but didn't resolve our issue.

### Option 3: Disable fsGroup 
Remove fsGroup from pod specs (breaks permissions for some apps).

### Option 4: Use local-path
Current workaround for monitoring stack.

## Recommendation
Upgrade Longhorn to 1.9.x to properly support fsGroup and move monitoring back to Longhorn storage as originally planned.