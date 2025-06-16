# Intel GPU Plugin K3s Compatibility Issue

## Problem Summary
The Intel GPU Device Plugin expects the standard Kubernetes kubelet socket path (`/var/lib/kubelet/device-plugins/kubelet.sock`) but K3s uses a different path (`/var/lib/rancher/k3s/agent/kubelet/`).

## Current State
- **k3s1**: ✅ Working - Has legacy `/var/lib/kubelet` directory with working socket (created June 15, 2025 during Longhorn incident)
- **k3s2**: ❌ Broken - Has legacy directory but no working socket
- **k3s3**: N/A - Uses NVIDIA GPU

## Root Cause
During the Longhorn CSI failure incident (June 14-15, 2025), someone attempted to fix kubelet path issues by creating standard Kubernetes directories. On k3s1, they somehow got a working kubelet socket in the legacy location, but this wasn't replicated on k3s2.

## Workaround
Jellyfin and other Intel GPU workloads are configured to run specifically on k3s1 where the plugin works.

## Proper Fix Options
1. **Patch Intel GPU Plugin**: Modify the DaemonSet to use K3s paths
2. **Socket Proxy**: Create a socat/systemd service to proxy between paths
3. **Clean Slate**: Remove legacy directories and properly configure the plugin for K3s

## Technical Debt
This is technical debt from the Longhorn incident. The legacy `/var/lib/kubelet` directories should not exist on K3s nodes and should be cleaned up as part of a proper fix.