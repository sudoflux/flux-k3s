# K3s Flux GitOps Repository

This repository contains the Flux configuration for a K3s cluster using Cilium as the CNI with BGP and Gateway API support.

## Cluster Configuration

### Nodes
- **k3s-master1** (R730): Control plane + storage node (192.168.10.30)
- **k3s1** (OptiPlex): Light compute worker with Intel QuickSync (192.168.10.21)
- **k3s2** (OptiPlex): Light compute worker with Intel QuickSync (192.168.10.23)
- **k3s3** (R630): GPU compute worker with NVIDIA Tesla T4, dual Xeon 2697A v4, 384GB RAM (192.168.10.31)

### Important K3s Configuration
K3s must be configured with `--disable=servicelb` to prevent conflicts with Cilium's load balancer functionality. This is set in `/etc/systemd/system/k3s.service` on the master node.

## Overview

Cilium is configured to:
- Act as the primary CNI for the k3s cluster
- Replace kube-proxy entirely
- Provide BGP peering with your router
- Manage LoadBalancer IP assignments from a dedicated pool
- Handle Gateway API for ingress routing
- Provide L2 announcements for local network

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

The LoadBalancer IP pool is configured with range: `192.168.10.224` - `192.168.10.239` (192.168.10.224/28)

Current allocation:
- Gateway API LoadBalancer: `192.168.10.224`
- Services are accessed via Gateway API HTTPRoutes
- All services use `*.fletcherlabs.net` domains

**Note**: Media apps use ClusterIP services internally and are exposed via Gateway API for HTTP/HTTPS access with proper domain routing.

## Troubleshooting

### Check BGP Status

1. Verify Cilium BGP is enabled:
```bash
kubectl -n kube-system exec -it deployment/cilium-operator -- cilium bgp peers
```

2. Check if ingress LoadBalancer IPs are assigned:
```bash
kubectl get svc -n media -o wide | grep cilium-ingress
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

2. **Ingress services not accessible**
   - Verify BGP routes are being advertised for ingress IPs
   - Check if ingress resources are properly configured
   - Ensure IP pool has available addresses for ingress controller

3. **Services not reachable via ingress**
   - Check Cilium operator logs: `kubectl logs -n kube-system deployment/cilium-operator`
   - Verify ingress controller is running: `kubectl get pods -n kube-system | grep cilium`
   - Check service endpoints: `kubectl get endpoints -n media`

## Service Configuration

Media apps use ClusterIP services and are exposed via Gateway API:

```yaml
# HTTPRoute example
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: app-http-route
  namespace: media
spec:
  parentRefs:
    - name: main-gateway
      namespace: networking
  hostnames:
    - "app.fletcherlabs.net"
  rules:
    - backendRefs:
        - name: app-service
          port: 8080
```

## Recent Changes

### 2025-06-12
- Added k3s3 node (R630) with NVIDIA Tesla T4 GPU
- Configured local storage on k3s3 with tiered approach (Optane, NVMe, SAS SSDs)
- Migrated Whisparr to k3s3 with Optane storage for better performance
- Disabled K3s ServiceLB to allow Cilium to handle all LoadBalancer services
- Fixed Gateway API connectivity issues