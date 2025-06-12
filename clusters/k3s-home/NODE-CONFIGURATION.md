# Node Configuration Strategy

This document outlines the node labeling and workload distribution strategy for the K3s cluster.

## Node Labels

Apply these labels to your nodes for proper workload scheduling:

### OptiPlex Nodes (k3s1, k3s2)
```bash
kubectl label nodes k3s1 node-type=compute workload=light
kubectl label nodes k3s2 node-type=compute workload=light
```

### GPU Node (k3s3)
```bash
kubectl label nodes k3s3 node-type=gpu gpu=nvidia
```

### Storage Node (r730)
```bash
kubectl label nodes r730 node-type=storage storage=high-performance
```

## Optional Node Taints

To ensure workloads only run on appropriate nodes, apply these taints:

```bash
# GPU node - only GPU workloads
kubectl taint nodes k3s3 gpu=nvidia:NoSchedule

# Storage node - only storage-intensive workloads
kubectl taint nodes r730 storage=high-performance:NoSchedule
```

## Workload Distribution

### GPU Node (k3s3)
- **Jellyfin**: Hardware transcoding with NVIDIA GPU
- Tolerates `gpu=nvidia:NoSchedule` taint

### Storage Node (R730)
- **SABnzbd**: Download client with high I/O requirements
- **Radarr**: Movie management
- **Sonarr**: TV show management
- **Lidarr**: Music management
- **Prowlarr**: Indexer management
- **Bazarr**: Subtitle management
- **Whisparr**: Adult content management
- All tolerate `storage=high-performance:NoSchedule` taint

### Compute Nodes (k3s1, k3s2)
- **Plex**: Media server (uses CPU transcoding)
- **Overseerr**: Request management (lightweight)
- These nodes handle general compute workloads

## Priority Classes

The following priority classes are configured:

- **critical** (1000): Media servers (Jellyfin, Plex)
- **high-priority** (900): Important services
- **medium-priority** (700): Default for regular workloads
- **low-priority** (500): Non-critical workloads
- **batch** (200): Batch jobs and maintenance tasks

## Storage Classes

- **local-ssd**: For high-performance local SSD storage on R730
- **local-hdd**: For local HDD storage on R730
- **NFS**: Default storage from NAS (192.168.10.100)

## Resource Limits

All applications now have resource requests and limits configured to ensure:
- Proper resource allocation
- Prevention of resource starvation
- Quality of Service (QoS) guarantees

## GPU Configuration

- Intel GPU plugin runs on all nodes (for nodes with Intel GPUs)
- NVIDIA GPU plugin runs only on nodes labeled with `gpu=nvidia`
- Jellyfin is configured to use NVIDIA GPU for hardware transcoding