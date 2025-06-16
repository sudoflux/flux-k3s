# Legacy Kubelet Directories on K3s Nodes

## Current State
Both k3s1 and k3s2 have `/var/lib/kubelet` directories that shouldn't exist on K3s systems. These were created during the Longhorn incident (June 15, 2025).

## Directory Contents
```
/var/lib/kubelet/
├── checkpoints/          # Kubelet checkpoint data
├── cpu_manager_state     # CPU manager state file
├── device-plugins/       # Device plugin sockets (INCLUDING the working kubelet.sock)
├── memory_manager_state  # Memory manager state file
├── plugins/              # Volume plugins
├── plugins_registry/     # Plugin registry
├── pod-resources/        # Pod resource sockets
└── pods/                 # Pod directories
```

## Why Not Remove Them?
1. **Intel GPU Plugin Depends on Them**: The plugin expects `/var/lib/kubelet/device-plugins/kubelet.sock`
2. **K3s is Now Using Them**: After our fixes, k3s-agent is actively maintaining these directories
3. **No Harm**: They're not causing issues and are being properly managed

## Proper Fix Would Require:
1. Patching Intel GPU Device Plugin to use K3s paths (`/var/lib/rancher/k3s/agent/kubelet/`)
2. Modifying all device plugins that expect standard Kubernetes paths
3. Potentially breaking other components that might depend on these paths

## Recommendation
Leave them as-is. They're now part of the working system and removing them would break GPU functionality. Document this as a K3s compatibility workaround.