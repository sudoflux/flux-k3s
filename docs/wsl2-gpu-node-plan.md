# WSL2 GPU Node Integration Plan

## Overview
Plan to add the desktop's RTX 4090 GPU to the K3s cluster by creating a dedicated WSL2 instance as a K3s node.

## Hardware Context
- **Desktop**: Windows machine with RTX 4090 (24GB VRAM)
- **Current Role**: SSH jump box via WSL2
- **Pending**: 10GbE NIC replacement

## Architecture Decision
After evaluation by the AI team (Claude, o3-mini, Gemini 2.5 Pro), the recommended approach is:

### WSL2 as K3s Node with Bridged Networking

**Why this approach:**
1. Leverages existing WSL2 GPU passthrough (highly optimized)
2. GPU remains available to Windows when not in use by K3s
3. No complex VM passthrough configuration
4. Appears as standard Linux node to K3s

**Why NOT other approaches:**
- **VM with PCI Passthrough**: Would make GPU unavailable to Windows
- **Network GPU Service**: Too much latency for training workloads
- **Windows Container Node**: Too complex for homelab (mixed OS cluster)

## Implementation Plan

### Phase 1: Windows Preparation (After NIC Replacement)

1. **Create Hyper-V External Virtual Switch**
   ```powershell
   # Run as Administrator
   New-VMSwitch -Name "WSLBridge" -NetAdapterName "Ethernet" -AllowManagementOS $true
   ```

2. **Configure WSL2 for Bridged Networking**
   Create `C:\Users\<Username>\.wslconfig`:
   ```ini
   [wsl2]
   memory=32GB
   processors=8
   networkingMode=bridged
   vmSwitch=WSLBridge
   
   [experimental]
   hostAddressLoopback=true
   ```

3. **Create Firewall Rules**
   ```powershell
   # K3s and Cilium ports
   New-NetFirewallRule -DisplayName "K3s API" -Direction Inbound -Protocol TCP -LocalPort 6443
   New-NetFirewallRule -DisplayName "SSH WSL" -Direction Inbound -Protocol TCP -LocalPort 22
   New-NetFirewallRule -DisplayName "BGP" -Direction Inbound -Protocol TCP -LocalPort 179
   New-NetFirewallRule -DisplayName "Kubelet" -Direction Inbound -Protocol TCP -LocalPort 10250
   New-NetFirewallRule -DisplayName "Cilium Health" -Direction Inbound -Protocol TCP -LocalPort 4240
   New-NetFirewallRule -DisplayName "Cilium VXLAN" -Direction Inbound -Protocol UDP -LocalPort 8472
   ```

### Phase 2: WSL2 Instance Setup

1. **Create New Instance**
   ```powershell
   wsl --install -d Ubuntu-22.04 --no-launch
   wsl --import k3s-gpu-node "$env:LOCALAPPDATA\WSL\k3s-gpu-node" <ubuntu-tar-path>
   ```

2. **Configure Static IP** (inside WSL2)
   `/etc/netplan/00-installer-config.yaml`:
   ```yaml
   network:
     ethernets:
       eth0:
         dhcp4: no
         addresses: [192.168.10.35/24]
         gateway4: 192.168.10.1
         nameservers:
           addresses: [192.168.1.1]
   ```

3. **Install NVIDIA Container Toolkit**
   ```bash
   # Add NVIDIA repository
   distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
   curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
   curl -s -L https://nvidia.github.io/libnvidia-container/$distribution/libnvidia-container.list | \
       sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
       sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
   
   # Install toolkit
   sudo apt update
   sudo apt install -y nvidia-container-toolkit
   
   # Configure for containerd
   sudo nvidia-ctk runtime configure --runtime=containerd
   ```

### Phase 3: K3s Integration

1. **Join Cluster**
   ```bash
   # Get token from master: sudo cat /var/lib/rancher/k3s/server/node-token
   curl -sfL https://get.k3s.io | K3S_URL=https://192.168.10.30:6443 K3S_TOKEN=<token> sh -s - agent \
     --node-name wsl-gpu-node \
     --node-label "gpu=nvidia" \
     --node-label "gpu-type=rtx4090" \
     --node-label "node-type=wsl"
   ```

2. **Deploy NVIDIA Device Plugin** (if not already present)
   ```yaml
   kubectl apply -f https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/v0.14.0/nvidia-device-plugin.yml
   ```

3. **Update DNS**
   - Add `wsl-gpu-node.fletcherlabs.net` → `192.168.10.35`

## Workload Distribution Strategy

With both GPUs available:

### Tesla T4 (k3s3) - Production Workloads
- Always available (no desktop competition)
- 16GB VRAM, 70W power efficient
- Ideal for: 24/7 services, smaller models, multiple concurrent workloads

### RTX 4090 (wsl-gpu-node) - Development/Burst
- Shared with desktop (gaming, creative work)
- 24GB VRAM, 450W high performance
- Ideal for: Large models, SDXL, experimental work, overflow capacity

### Node Selectors
```yaml
# For T4 (always available)
nodeSelector:
  gpu-type: tesla-t4

# For 4090 (high performance)
nodeSelector:
  gpu-type: rtx4090

# For any GPU
nodeSelector:
  gpu: nvidia
```

## Considerations

1. **Resource Sharing**: RTX 4090 is shared between Windows and K3s
2. **Power Usage**: Combined GPU power draw ~520W under full load
3. **Network**: WSL2 node requires stable bridged networking
4. **Maintenance**: Windows updates may affect WSL2 configuration

## Current Status
- **Planned**: Implementation pending 10GbE NIC replacement
- **Documented**: This plan created 2025-06-13
- **Next Steps**: Execute Phase 1 after hardware upgrade