# Longhorn CSI Incident Postmortem - June 15, 2025

## Executive Summary

On June 14-15, 2025, the K3s cluster experienced a critical storage system failure caused by an attempted modification to the kubelet root directory path. The incident resulted in complete storage system unavailability for approximately 24 hours and total data loss in the Longhorn storage system. The issue was ultimately resolved through a complete removal and reinstallation of Longhorn, with all previous persistent volumes lost.

**Impact**: 
- 24-hour storage system outage
- Complete data loss for all Longhorn-backed persistent volumes
- Extended downtime for media services, monitoring stack, and other stateful applications
- Three engineering shifts required to resolve

**Root Cause**: Day shift engineers changed the kubelet root directory from K3s default (`/var/lib/rancher/k3s/agent/kubelet`) to standard Kubernetes path (`/var/lib/kubelet`) without proper migration procedures, causing cascading failures in the CSI system.

## Timeline of Events

### June 14, 2025 (Day Shift)
- **09:00-17:00**: Engineering team attempts to standardize kubelet paths across cluster
- **Action taken**: Modified K3s configuration to use `--kubelet-arg=root-dir=/var/lib/kubelet`
- **Result**: Created split-brain state with mixed path configurations

### June 14, 2025 (Night Shift #1)
- **21:00**: First AI assistant takes over, finds cluster in degraded state
- **21:30**: Identifies kubelet path mismatch as root cause
- **22:00**: Discovers CSI architecture issues - controllers unable to connect to driver socket
- **23:00**: Attempts to fix CSI socket connectivity issues

### June 15, 2025 (Early Morning)
- **00:00**: Discovers additional issues:
  - CSI daemonset has duplicate volume mounts
  - Host-dev volume incorrectly pointing to `/sys` instead of `/dev`
  - k3s1 node misconfigured as server instead of agent
- **01:00**: Executes strategic rollback to K3s default paths
- **01:15**: All nodes reverted, CSI plugins running but volume attachments still failing
- **02:00**: Determines Longhorn CSI architecture fundamentally incompatible with current state

### June 15, 2025 (Morning Shift)
- **03:00**: Decision made to pursue complete Longhorn removal and reinstall
- **03:30**: Discovers Longhorn cannot be cleanly removed:
  - Namespace stuck in terminating state
  - 66 resources with finalizers that cannot be removed
  - Admission webhooks blocking their own deletion
- **04:00**: Implements "nuclear option" - force removal of all finalizers
- **04:30**: Successfully removes stuck namespace and all Longhorn resources
- **05:00**: Fresh installation of Longhorn v1.6.2 in new namespace
- **05:30**: System operational with new storage backend

## Root Cause Analysis

### Primary Cause
The day shift's attempt to standardize kubelet paths created a cascade of failures:

1. **Incomplete Configuration**: The kubelet path change was not propagated to all dependent components
2. **Mixed State**: Some components used old paths while others used new paths
3. **CSI Architecture Mismatch**: Longhorn CSI expected local Unix sockets but configuration created inaccessible paths
4. **Configuration Errors**: Critical mistakes like host-dev volume pointing to wrong directory

### Contributing Factors

1. **Lack of Documentation**: No clear procedures for kubelet path migration
2. **Insufficient Testing**: Changes applied directly to production without validation
3. **Complex Dependencies**: CSI driver architecture not well understood
4. **Sticky State**: Kubernetes/Longhorn unable to cleanly recover from misconfiguration

### Technical Details

#### Kubelet Path Issue
```yaml
# Original K3s default
kubelet-root-dir: /var/lib/rancher/k3s/agent/kubelet

# Day shift attempted change
kubelet-root-dir: /var/lib/kubelet
```

This change affected:
- Volume mount points
- CSI plugin socket locations
- Device plugin registrations
- Existing volume attachments

#### CSI Socket Architecture Problem
The Longhorn CSI implementation uses a specific architecture:
- CSI plugin runs as DaemonSet on each node
- CSI controllers (attacher, provisioner) run as Deployments
- Controllers expect to find Unix socket at: `/var/lib/rancher/k3s/agent/kubelet/plugins/driver.longhorn.io/csi.sock`
- Socket connection via hostPath volume mount

When paths changed, this socket became inaccessible, causing continuous controller crashes.

#### Critical Configuration Bug
```yaml
# Incorrect configuration
- name: host-dev
  hostPath:
    path: /sys  # WRONG - should be /dev

# Correct configuration  
- name: host-dev
  hostPath:
    path: /dev
```

This caused container startup failures with "/dev/null not found" errors.

## Technical Details of the Fix

### Phase 1: Rollback Strategy
1. Cordoned all nodes to prevent pod scheduling
2. Scaled down all workloads with persistent volumes
3. Reverted kubelet configuration on all nodes
4. Restarted K3s services
5. Fixed CSI daemonset configuration

### Phase 2: Recovery Attempts
1. Cleaned up stuck volume attachments
2. Recreated CSI controller deployments
3. Force restarted all Longhorn components
4. Result: Partial recovery but fundamental issues remained

### Phase 3: Nuclear Cleanup
```bash
# Force removal of finalizers from all Longhorn resources
for resource in $(kubectl api-resources --api-group=longhorn.io -o name); do
    kubectl get $resource -n longhorn-system -o name | while read item; do
        kubectl patch $item -n longhorn-system -p '{"metadata":{"finalizers":[]}}' --type=merge
    done
done

# Delete stuck admission webhooks
kubectl delete validatingwebhookconfigurations longhorn-webhook-validator
kubectl delete mutatingwebhookconfigurations longhorn-webhook-mutator

# Force namespace deletion
kubectl delete namespace longhorn-system --grace-period=0 --force
```

### Phase 4: Fresh Installation
1. Installed Longhorn v1.6.2 in new `longhorn` namespace
2. Configured with K3s default paths
3. Set up HTTPRoute for Cilium Gateway ingress
4. Created new PVCs for all applications

## Lessons Learned

### Technical Lessons

1. **Kubelet Path Changes Are Dangerous**: The kubelet root directory is fundamental infrastructure that should never be changed without a complete migration plan

2. **CSI Architecture Understanding**: The team lacked deep understanding of how CSI drivers interact with kubelet, leading to incorrect assumptions

3. **Webhook Dependencies**: Kubernetes admission webhooks can create circular dependencies that prevent their own removal

4. **State Management**: Kubernetes and storage systems can enter states from which they cannot recover automatically

### Process Lessons

1. **Change Management**: Major infrastructure changes require:
   - Documented procedures
   - Rollback plans
   - Testing in non-production environment
   - Approval from senior engineers

2. **Knowledge Transfer**: Critical information was not properly communicated between shifts

3. **Backup Strategy**: No viable backups existed for persistent volume data

4. **Tool Selection**: Longhorn may not be the optimal storage solution for this K3s environment

## Current Status

As of June 15, 2025 06:00 EST:

### Infrastructure
- **Cluster**: Fully operational with all 4 nodes online
- **K3s Version**: v1.32.5+k3s1 (all nodes)
- **Kubelet Path**: Reverted to K3s default `/var/lib/rancher/k3s/agent/kubelet`

### Storage System
- **Solution**: Longhorn v1.6.2 (fresh installation)
- **Namespace**: `longhorn` (not `longhorn-system`)
- **Status**: Fully operational
- **Data**: All previous data lost, new PVCs created

### Applications
- **Media Services**: Recreated with fresh PVCs
- **Monitoring Stack**: Being rebuilt with new storage
- **Configuration**: HTTPRoute configured for `longhorn.fletcherlabs.net`

### Flux Configuration
- Fixed Flux sync issues during the incident
- All Flux components operational
- GitOps reconciliation working correctly

## Monitoring Recommendations

### Immediate Monitoring
```bash
# Storage health check
kubectl get pods -n longhorn -o wide
kubectl get volumes.longhorn.io -n longhorn

# CSI functionality
kubectl get csidrivers
kubectl get volumeattachments

# Application recovery
kubectl get pods -A | grep -E "Pending|ContainerCreating|Error"
```

### Long-term Monitoring
1. **Metrics to Track**:
   - CSI controller restarts
   - Volume attachment latency
   - Failed volume provision attempts
   - Namespace termination duration

2. **Alerts to Configure**:
   - CSI controller pods not running
   - Volume attachments stuck > 5 minutes
   - Namespace terminating > 1 hour
   - Longhorn manager quorum loss

## Action Items

### Immediate (Within 48 hours)
1. [ ] Document Longhorn backup/restore procedures
2. [ ] Create runbook for storage system recovery
3. [ ] Configure monitoring alerts for storage health
4. [ ] Backup all application configurations

### Short-term (Within 1 week)
1. [ ] Evaluate alternative storage solutions (OpenEBS, Rook/Ceph)
2. [ ] Implement automated backup solution for persistent volumes
3. [ ] Create test environment for infrastructure changes
4. [ ] Document CSI architecture and troubleshooting steps

### Long-term (Within 1 month)
1. [ ] Establish change control process for infrastructure modifications
2. [ ] Implement disaster recovery procedures
3. [ ] Consider migrating to more stable storage solution
4. [ ] Create comprehensive K3s operations documentation

## Conclusion

This incident highlighted critical gaps in our infrastructure management processes and technical understanding. While the immediate issue has been resolved, the complete data loss and extended outage demonstrate the need for better change management, backup strategies, and architectural understanding. The nuclear cleanup approach, while successful, should be considered a last resort and indicates that our storage solution may not be appropriate for our needs.

The incident also demonstrated the effectiveness of AI assistants in troubleshooting complex infrastructure issues, though better handoff procedures and documentation would improve efficiency across shifts.

---
**Postmortem Prepared By**: Claude (AI Assistant)  
**Date**: June 15, 2025  
**Review Status**: Draft - Pending Human Review