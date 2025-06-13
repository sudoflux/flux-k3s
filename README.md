# K3s Flux GitOps Repository

This repository contains the Flux GitOps configuration for a K3s homelab cluster running media services, AI workloads, and observability stack. It uses Cilium as the CNI with BGP and Gateway API support.

## Cluster Configuration

### Nodes
- **k3s-master1** (VM on R730): Control plane (192.168.10.30)
- **k3s1** (OptiPlex): Light compute worker with Intel QuickSync (192.168.10.21)
- **k3s2** (OptiPlex): Light compute worker with Intel QuickSync (192.168.10.23)
- **k3s3** (R630): GPU compute worker with NVIDIA Tesla T4, dual Xeon E5-2697A v4, 384GB RAM (192.168.10.31)

### Storage
- **R730**: NFS storage provider
  - `/mnt/nvme_storage`: App configurations (backed by NVMe)
  - `/mnt/rust/media`: Media files (backed by HDD array)
- **Longhorn**: Distributed block storage across nodes
- **Local Storage**: k3s3 has tiered local storage (Optane, NVMe, SAS SSDs)

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

## Repository Structure

```
clusters/k3s-home/
├── apps/               # Application deployments
│   ├── auth/          # Authentik authentication
│   ├── media/         # Media services (Jellyfin, Plex, *arr apps)
│   ├── ai/            # AI workloads (Ollama, Open WebUI, Automatic1111)
│   └── monitoring/    # Observability stack
├── infrastructure/     # Core infrastructure (CNI, CRDs)
└── infrastructure-runtime/  # Runtime configs (storage, Gateway API)
```

## Quick Start

### Access Services
All services are accessible via HTTP at their respective domains:
- Media services: `http://<service>.fletcherlabs.net`
- Grafana: `http://grafana.fletcherlabs.net` (admin / encrypted password)
- Authentik: `http://authentik.fletcherlabs.net` (initial setup required)

### Managing the Cluster
```bash
# SSH to any node
ssh k3s1  # or k3s2, k3s3, k3s-master1

# Check cluster status
sudo kubectl get nodes
sudo kubectl get pods -A

# Force Flux reconciliation
sudo kubectl annotate kustomization <name> -n flux-system \
  reconcile.fluxcd.io/requestedAt=$(date +%s) --overwrite
```

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

## Deployed Services

### Media Stack
- **Jellyfin**: Media server (jellyfin.fletcherlabs.net)
- **Plex**: Alternative media server (plex.fletcherlabs.net)
- **Sonarr**: TV show management (sonarr.fletcherlabs.net)
- **Radarr**: Movie management (radarr.fletcherlabs.net)  
- **Prowlarr**: Indexer management (prowlarr.fletcherlabs.net)
- **Whisparr**: Adult content management (whisparr.fletcherlabs.net)
- **SABnzbd**: Usenet downloader (sabnzbd.fletcherlabs.net)
- **Transmission**: BitTorrent client (transmission.fletcherlabs.net)

### AI/ML Stack
- **Ollama**: LLM inference engine with llama3.2:3b
- **Open WebUI**: Chat interface for LLMs (openwebui.fletcherlabs.net)
- **Automatic1111**: Stable Diffusion WebUI (automatic1111.fletcherlabs.net)

### Infrastructure Services
- **Authentik**: Identity provider and SSO (authentik.fletcherlabs.net)
- **Longhorn**: Distributed block storage with tiered storage classes
- **Velero**: Backup and disaster recovery with MinIO backend

### Observability Stack
- **Prometheus**: Metrics collection and storage
- **Grafana**: Visualization and dashboards (grafana.fletcherlabs.net)
- **Loki**: Log aggregation
- **DCGM Exporter**: GPU metrics monitoring

## Security

- **SOPS**: Age encryption for secrets management
- **GitOps**: All changes tracked in Git, deployed by Flux
- **Network Policies**: Cilium network policies for pod-to-pod communication

## Recent Changes

### 2025-06-13
- Completed Week 3 observability implementation
- Deployed kube-prometheus-stack with Grafana
- Added NVIDIA DCGM exporter for GPU monitoring
- Deployed Loki for centralized log aggregation
- Fixed Flux dependency chain issues
- Worked around k3s3 Longhorn CSI driver issues

### 2025-06-12
- Added k3s3 node (R630) with NVIDIA Tesla T4 GPU
- Configured local storage on k3s3 with tiered approach (Optane, NVMe, SAS SSDs)
- Migrated Whisparr to k3s3 with Optane storage for better performance
- Disabled K3s ServiceLB to allow Cilium to handle all LoadBalancer services
- Fixed Gateway API connectivity issues

## Important Notes

1. **SOPS Age Key**: The encryption key is located at `~/.config/sops/age/keys.txt` - **BACK THIS UP!**
2. **Authentik 2FA**: Do not enable 2FA/forward auth until all infrastructure work is complete
3. **Storage Classes**: 
   - `local-path`: Default K3s local storage (no replication)
   - `longhorn-optane`: Ultra-fast storage on k3s3 only
   - `longhorn-nvme`: High-performance NVMe storage
   - `longhorn-sas-ssd`: Standard SSD storage
   - `longhorn-replicated`: Replicated across multiple nodes
4. **GPU Sharing**: All AI workloads share the Tesla T4 via time-slicing

## Documentation

For detailed documentation, see:
- [CLUSTER-SETUP.md](./CLUSTER-SETUP.md) - Comprehensive cluster documentation
- [docs/](./docs/) - Weekly implementation summaries
- [Implementation Roadmap](~/k3s-homelab-implementation-roadmap.md) - Full project plan