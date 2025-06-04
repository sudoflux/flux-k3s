# Cilium BGP Configuration

This directory contains the Cilium CNI configuration with BGP support for LoadBalancer services.

## Overview

Cilium is configured to:
- Act as the primary CNI for the k3s cluster
- Provide BGP peering with your router (UDM-SE)
- Manage LoadBalancer IP assignments from a dedicated pool
- Advertise service IPs via BGP

## Configuration Files

- `helmrelease.yaml` - Main Cilium deployment configuration
- `bgp-peering.yaml` - BGP peering policy for router communication
- `ip-pool.yaml` - LoadBalancer IP address pool
- `namespace.yaml` - Creates the kube-system namespace
- `kustomization.yaml` - Kustomize configuration

## Prerequisites

### 1. Node Labeling for BGP

**IMPORTANT**: BGP will only work on nodes that have the proper label. You must label your nodes:

```bash
kubectl label node <node-name> bgp=enabled
```

To verify your nodes are labeled:
```bash
kubectl get nodes --show-labels | grep bgp=enabled
```

### 2. Router BGP Configuration

Your router (UDM-SE) must be configured with:
- BGP enabled
- AS Number: 64513
- Neighbor IP: Your k3s node IP(s)
- Neighbor AS: 64512

## IP Address Allocation

The LoadBalancer IP pool is configured with range: `192.168.10.40` - `192.168.10.55`

Current allocation:
- `192.168.10.40` - Plex
- `192.168.10.41` - Sonarr
- `192.168.10.42` - Radarr
- `192.168.10.43` - Prowlarr
- `192.168.10.44` - SABnzbd
- `192.168.10.45` - Bazarr
- `192.168.10.46` - Lidarr
- `192.168.10.47` - Overseerr
- `192.168.10.48-55` - Available for future services

## Troubleshooting

### Check BGP Status

1. Verify Cilium BGP is enabled:
```bash
kubectl -n kube-system exec -it deployment/cilium-operator -- cilium bgp peers
```

2. Check if LoadBalancer IPs are assigned:
```bash
kubectl get svc -A -o wide | grep LoadBalancer
```

3. Verify BGP routes on your router:
```bash
# On UDM-SE
show ip bgp summary
show ip bgp routes
```

### Common Issues

1. **No BGP peers established**
   - Ensure nodes are labeled with `bgp=enabled`
   - Verify router BGP configuration
   - Check firewall rules allow BGP (TCP port 179)

2. **LoadBalancer IPs not accessible**
   - Verify BGP routes are being advertised
   - Check if services have the correct annotations
   - Ensure IP pool has available addresses

3. **Services stuck in Pending**
   - Check Cilium operator logs: `kubectl logs -n kube-system deployment/cilium-operator`
   - Verify IP pool configuration
   - Ensure service has proper annotations

## Service Configuration

To enable LoadBalancer for a service, add:

```yaml
service:
  main:
    type: LoadBalancer
    annotations:
      io.cilium/lb-ipam-ips: "192.168.10.XX"  # Specific IP from pool
```

Or let Cilium auto-assign:

```yaml
service:
  main:
    type: LoadBalancer
    # Cilium will automatically assign an IP from the pool
```