# ADR-001: Prevent systemd-networkd from Managing CNI Interfaces

## Status
Accepted and Implemented

## Context
On June 13, 2025, node k3s1 experienced a complete network failure that was initially misdiagnosed as a Longhorn CSI bug. Investigation revealed that systemd-networkd renamed a temporary CNI interface "tmpe2695" to "eth0", causing:
- Node disconnection from the cluster
- Pod networking failures
- Service disruption

The root cause was systemd-networkd attempting to manage interfaces created by the Cilium CNI, leading to naming conflicts and network instability.

## Decision
Implement systemd-networkd configuration rules on ALL nodes to explicitly mark CNI-created interfaces as unmanaged.

## Implementation
Created two networkd configuration files on all nodes:

1. `/etc/systemd/network/10-cni-veth.network` - Ignores veth interfaces
2. `/etc/systemd/network/15-cni-lxc.network` - Ignores lxc* interfaces

## Consequences

### Positive
- Prevents systemd-networkd from interfering with CNI operations
- Eliminates risk of interface naming conflicts
- Ensures stable pod networking
- Simple, declarative configuration

### Negative
- Requires manual configuration on new nodes
- Must be maintained separately from Kubernetes manifests

## Alternatives Considered
1. **Disable systemd-networkd entirely** - Rejected: May be needed for host networking
2. **Use different interface naming** - Rejected: CNI controls naming
3. **Switch to different CNI** - Rejected: Cilium provides required features

## References
- Incident log: `/home/josh/flux-k3s/cilium-bugtool-20250614-072834.704+0000-UTC-3274465140/cmd/dmesg---time-format=iso.md`
- Fix implementation: Commit 60d63fe