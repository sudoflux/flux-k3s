# High Availability Plan for K3s Cluster

## Executive Summary
This document outlines the plan to transition from a single control-plane node to a highly available 3-node control plane architecture, addressing the current single point of failure (SPOF) in the cluster.

## Current Architecture

### Control Plane
- **Single Node**: k3s1 (master)
- **Risk**: Complete cluster failure if control plane node fails
- **etcd**: Embedded single instance

### Worker Nodes  
- k3s2, k3s3, k3s4 (workers)
- Applications distributed across workers
- GPU workloads pinned to specific nodes

## Target HA Architecture

### 3-Node Control Plane
```
┌─────────────┐  ┌─────────────┐  ┌─────────────┐
│    k3s1     │  │    k3s2     │  │    k3s3     │
│  (master)   │  │  (master)   │  │  (master)   │
│    etcd     │  │    etcd     │  │    etcd     │
└─────────────┘  └─────────────┘  └─────────────┘
       │                │                │
       └────────────────┴────────────────┘
                        │
                   Load Balancer
                        │
                ┌───────────────┐
                │     k3s4      │
                │   (worker)    │
                └───────────────┘
```

### Key Components
1. **etcd Cluster**: 3-node etcd cluster with automatic failover
2. **API Server HA**: Multiple API servers behind load balancer
3. **Load Balancer**: HAProxy or MetalLB for API server access
4. **Quorum**: Requires 2/3 nodes for cluster operations

## Resource Requirements

### Hardware Requirements per Control Plane Node
- **CPU**: Minimum 2 cores, recommended 4 cores
- **Memory**: Minimum 4GB, recommended 8GB
- **Storage**: 50GB SSD for etcd performance
- **Network**: Gigabit ethernet, low latency between nodes

### Current Resource Analysis
```bash
# Node: k3s1 (current master)
- CPU: 8 cores available
- Memory: 32GB available
- Role: Would remain control plane

# Node: k3s2 
- CPU: 8 cores available  
- Memory: 16GB available
- Role: Promote to control plane

# Node: k3s3
- CPU: 8 cores (NVIDIA GPU node)
- Memory: 32GB available
- Role: Promote to control plane (GPU workloads compatible)

# Node: k3s4
- CPU: 4 cores
- Memory: 8GB available  
- Role: Remain as worker (insufficient resources)
```

## Implementation Plan

### Phase 1: Preparation (Week 1)
1. **Backup Current Cluster**
   ```bash
   # Backup etcd
   k3s etcd-snapshot save --name pre-ha-backup
   
   # Backup Flux state
   flux create backup
   ```

2. **Network Preparation**
   - Configure firewall rules for etcd ports (2379, 2380)
   - Ensure time synchronization (NTP) across all nodes
   - Test network latency between nodes (<10ms required)

3. **Load Balancer Setup**
   - Deploy HAProxy or MetalLB
   - Configure health checks for API servers
   - Virtual IP: 192.168.1.200 (example)

### Phase 2: Control Plane Expansion (Week 2)

1. **Promote k3s2 to Control Plane**
   ```bash
   # On k3s2
   curl -sfL https://get.k3s.io | sh -s - server \
     --server https://192.168.1.200:6443 \
     --token <node-token> \
     --datastore-endpoint=<etcd-endpoints>
   ```

2. **Promote k3s3 to Control Plane**
   ```bash
   # On k3s3
   curl -sfL https://get.k3s.io | sh -s - server \
     --server https://192.168.1.200:6443 \
     --token <node-token> \
     --datastore-endpoint=<etcd-endpoints>
   ```

3. **Verify etcd Cluster Health**
   ```bash
   k3s kubectl exec -n kube-system etcd-k3s1 -- etcdctl \
     --endpoints=https://127.0.0.1:2379 \
     --cacert=/var/lib/rancher/k3s/server/tls/etcd/server-ca.crt \
     --cert=/var/lib/rancher/k3s/server/tls/etcd/server-client.crt \
     --key=/var/lib/rancher/k3s/server/tls/etcd/server-client.key \
     endpoint health
   ```

### Phase 3: Workload Redistribution (Week 3)

1. **Taint Control Plane Nodes**
   ```bash
   kubectl taint nodes k3s1 k3s2 k3s3 \
     node-role.kubernetes.io/control-plane=:NoSchedule
   ```

2. **Update Critical Workloads**
   - Add tolerations for control plane nodes to critical system pods
   - Ensure GPU workloads remain on k3s3 with proper tolerations

3. **Resource Allocation**
   - Reserve 2GB memory and 1 CPU for control plane operations
   - Adjust resource requests/limits for existing workloads

### Phase 4: Testing & Validation (Week 4)

1. **Failover Testing**
   - Simulate control plane node failure
   - Verify automatic failover (target: <30 seconds)
   - Test etcd leader election

2. **Performance Testing**
   - API server response times
   - etcd latency measurements
   - Cluster operation benchmarks

3. **Backup/Restore Testing**
   - Test etcd snapshot restore
   - Verify Flux reconciliation after restore

## Risk Mitigation

### During Migration
1. **Rollback Plan**: Keep original k3s1 as sole master until validation
2. **Backup Strategy**: Hourly etcd snapshots during migration
3. **Monitoring**: Enhanced monitoring during transition

### Post-Migration
1. **etcd Maintenance**: Regular defragmentation and backups
2. **Certificate Management**: Monitor certificate expiration
3. **Capacity Planning**: Monitor control plane resource usage

## Success Criteria

1. **Availability**: 99.9% API server uptime
2. **Failover Time**: <30 seconds for control plane failover
3. **Performance**: No degradation in API response times
4. **Stability**: 30 days without control plane issues

## Maintenance Procedures

### Regular Tasks
- Weekly etcd backups to external storage
- Monthly certificate rotation checks
- Quarterly disaster recovery drills

### Monitoring Alerts
- etcd cluster health
- API server latency >100ms
- Control plane CPU/Memory >80%
- Certificate expiration <30 days

## Cost-Benefit Analysis

### Benefits
- Eliminates single point of failure
- Enables zero-downtime control plane updates
- Improves cluster resilience
- Supports larger workload scale

### Costs
- Additional CPU/Memory overhead (~6GB RAM, 3 CPU cores)
- Increased network traffic for etcd replication
- More complex troubleshooting
- Additional monitoring requirements

## Timeline
- **Week 1**: Preparation and backups
- **Week 2**: Control plane expansion
- **Week 3**: Workload redistribution  
- **Week 4**: Testing and validation
- **Week 5**: Production cutover
- **Week 6-9**: Stability monitoring

## Conclusion
This HA migration addresses the critical SPOF in the current architecture while maintaining workload stability. The phased approach minimizes risk and allows for rollback at each stage. The target architecture provides enterprise-grade availability suitable for production workloads.