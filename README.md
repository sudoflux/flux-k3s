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

The LoadBalancer IP pool is configured with range: `192.168.90.40` - `192.168.90.55`

Current allocation:
- Services will be dynamically assigned IPs from the pool
- All ingresses share IPs based on the configured mode (shared/dedicated)
- Access services via DNS names that resolve to the LoadBalancer IPs

**Note**: Media apps use ClusterIP services internally and are exposed via Cilium ingress controller for HTTP/HTTPS access with proper domain routing.

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

Media apps use ClusterIP services and are exposed via Cilium ingress:

```yaml
# Service (ClusterIP - default)
service:
  main:
    controller: main
    ports:
      http:
        port: 8080

# Ingress
ingress:
  main:
    enabled: true
    className: cilium
    annotations:
      cilium.io/preserve-service-port: "true"
    hosts:
      - host: app.example.com
        paths:
          - path: /
            service:
              name: app-service
              port: 8080
```

For dedicated LoadBalancer services (if needed), use:
```yaml
service:
  main:
    type: LoadBalancer
    # Cilium will automatically assign an IP from the pool
```