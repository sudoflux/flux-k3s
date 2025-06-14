# Network Architecture & Infrastructure Overview

## Core Components

### CNI: Cilium
- **Version**: 1.17.4
- **Mode**: Full kube-proxy replacement with eBPF
- **IPAM**: Cluster-pool mode with Pod CIDR: 10.42.0.0/16

### Ingress Strategy: Cilium Gateway API
- **NO nginx ingress controller is deployed**
- All external service exposure uses Gateway API (HTTPRoute)
- Main gateway: `main-gateway` in `networking` namespace (IP: 192.168.10.224)

## Node Network Configuration

### Physical Network Interfaces

| Node | Primary NIC | Type | Notes |
|------|------------|------|-------|
| k3s-master1 | enp2s0 | 1GbE onboard | Active |
| k3s1 | enx6c1ff71be8c8 | 2.5GbE USB | Onboard NIC unplugged |
| k3s2 | enx8cae4cdd5def | 2.5GbE USB | Onboard NIC unplugged |
| k3s3 | enp2s0 | 1GbE onboard | Active |

### Critical Configuration: systemd-networkd Protection

Due to the June 13, 2025 incident where systemd-networkd interfered with CNI interfaces, the following protective configurations are applied to ALL nodes:

```bash
# /etc/systemd/network/10-cni-veth.network
[Match]
Driver=veth

[Link]
Unmanaged=yes

# /etc/systemd/network/15-cni-lxc.network
[Match]
Name=lxc*

[Link]
Unmanaged=yes
MACAddressPolicy=none
```

**IMPORTANT**: These configurations prevent systemd-networkd from managing CNI-created interfaces, which can cause catastrophic network failures.

## Traffic Flow

### Internal Cluster Traffic
- Pod-to-Pod: Direct routing via Cilium eBPF
- Service-to-Pod: Cilium service maps (no iptables)
- Network Policies: Cilium CRDs (CiliumNetworkPolicy)

### External Traffic (Ingress)
1. External client → Gateway IP (192.168.10.224)
2. Cilium Gateway processes HTTPRoute rules
3. Traffic forwarded to backend service
4. Global HTTP→HTTPS redirect active for *.fletcherlabs.net

### Observability
- Hubble UI: https://hubble.fletcherlabs.net
- Metrics enabled: dns:query, drop, tcp, flow, port-distribution, icmp

## BGP Configuration
- BGP Control Plane: Enabled
- L2 Announcements: Enabled
- Configuration via CiliumBGPPeeringPolicy CRDs

## Load Balancer
- Mode: SNAT (changed from DSR for vxlan compatibility)
- L7 Backend: Envoy