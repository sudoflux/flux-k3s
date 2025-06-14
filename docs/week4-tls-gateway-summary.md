# Week 4 Summary - TLS, Gateway API, and Incident Response

**Week**: June 10-16, 2025  
**Focus**: TLS Implementation and Critical Issue Resolution  
**Status**: Completed with significant learnings

## Executive Summary

Week 4 diverged significantly from the original plan due to a critical incident that was initially misdiagnosed. What appeared to be a K3s v1.32.5 CSI driver bug was actually a node networking failure. The week concluded with all major issues resolved, HTTPS/TLS working, and comprehensive documentation updates.

## Completed Objectives

### 1. TLS/HTTPS Configuration ✅
- Implemented cert-manager with Let's Encrypt
- Configured wildcard certificate for `*.fletcherlabs.net`
- Set up Gateway API with proper TLS termination
- **Key Learning**: Cilium Gateway API requires specific features:
  - `enable-gateway-api-alpn: "true"` for HTTP/2 and gRPC
  - `enable-gateway-api-app-protocol: "true"` for backend protocol selection

### 2. Critical Incident Resolution ✅
- **Initial Diagnosis**: K3s v1.32.5 CSI driver incompatibility
- **Actual Issue**: k3s1 node networking failure
- **Resolution**: Node isolation and self-recovery
- **Key Learning**: Always verify Layer 3/4 connectivity before debugging application protocols

### 3. Velero Backup Improvements ✅
- Fixed MinIO configuration (secret name mismatch, credential format)
- Completed Backblaze B2 integration
- Created successful offsite backups
- Deleted conflicting VSL configuration

### 4. Additional Fixes ✅
- Enabled k3s3 BGP peering (missing label)
- Resolved Bazarr deployment (scaled to 0)
- Fixed Longhorn faulted volumes on monitoring stack
- Enabled node scheduling for k3s3 in Longhorn

## Deviations from Plan

### What Was Planned
1. Focus on TLS/certificate implementation
2. Begin Authentik configuration
3. Complete Velero offsite setup
4. Start planning Week 5 storage work

### What Actually Happened
1. Major troubleshooting effort for misdiagnosed CSI issue
2. Discovery and resolution of k3s1 networking problem
3. Complete overhaul of troubleshooting documentation
4. Gateway API configuration debugging (ALPN/app-protocol)

## Technical Discoveries

### 1. Cilium Gateway API Requirements
```yaml
# Required configuration for full Gateway API support
data:
  enable-gateway-api: "true"
  enable-gateway-api-alpn: "true"        # For HTTP/2 and gRPC
  enable-gateway-api-app-protocol: "true" # For backend protocol selection
```

### 2. Node Health Masquerading as Application Issues
- Network failures can present as storage/CSI problems
- Symptom: "CSI driver not registered"
- Root cause: Kubelet unable to reach Longhorn services
- Lesson: Start troubleshooting at the network layer

### 3. GPU Architecture Clarification
- Tesla T4 uses time-slicing (nvidia.com/gpu: 4)
- No memory isolation between GPU workloads
- Risk of memory-hungry jobs affecting others
- Future RTX 4090 addition will provide better isolation

## Remaining Issues

### Priority 0 - Critical
1. **Flux Reconciliation Failures**
   - Authentik missing secret
   - Intel GPU plugin CRDs not installed

### Priority 1 - High  
2. **Root Cause Unknown**
   - k3s1 network failure cause not identified
   - Risk of recurrence

3. **Monitoring on Ephemeral Storage**
   - Using local-path instead of Longhorn
   - Data loss risk

### Priority 2 - Medium
4. **No High Availability**
   - Single control plane
   - Single storage server

5. **Authentik Not Configured**
   - Deployed but needs setup
   - No 2FA until stable

## Lessons Learned

### Technical
1. **Troubleshooting Methodology**: Start with basic connectivity, not application symptoms
2. **Gateway API**: Requires specific Cilium features for production use
3. **Node Issues**: Can cascade into cluster-wide symptoms
4. **Documentation**: Initial diagnosis can be wrong - update docs promptly

### Process
1. **Incident Response**: Node isolation is effective for containing issues
2. **Root Cause Analysis**: Essential to prevent recurrence
3. **Parallel Investigation**: Often reveals unrelated issues (MinIO, VSL)
4. **Version Changes**: Extremely risky without comprehensive backups

## Metrics

- **Incidents**: 1 major (k3s1 networking)
- **MTTR**: ~4 hours (including misdiagnosis time)
- **Changes**: 15+ configuration fixes
- **Documentation**: 4 major updates, 1 rename

## Week 5 Preview

### Original Plan (Now Adjusted)
- ~~Fix Longhorn CSI issue~~ ✅ Not actually broken
- ~~Storage migrations~~ ⏸️ Deprioritized
- ~~Disaster recovery testing~~ ⏸️ B2 already tested

### Updated Priorities
1. **P0**: Fix Flux reconciliation (2 issues)
2. **P1**: k3s1 root cause analysis
3. **P1**: Monitoring storage migration
4. **P2**: Authentik configuration
5. **P2**: HA planning

### Key Decisions Needed
1. Should we investigate k3s1 logs immediately or monitor for recurrence?
2. Is monitoring storage migration urgent given current stability?
3. When to schedule Authentik configuration session?

## Documentation Updates

### Created/Updated
1. **CLUSTER-SETUP.md**: Complete restructure with AAR log
2. **ai-team-onboarding.md**: Removed incorrect CSI information
3. **storage-and-node-health-troubleshooting.md**: Renamed and rewritten
4. **next-session-tasks.md**: Reprioritized based on actual state

### New Sections
- AAR (After Action Review) log format
- Storage architecture tiers
- GPU architecture details
- Cilium Gateway API configuration

## Team Notes

This week demonstrated the importance of:
- Not jumping to conclusions about root causes
- Maintaining comprehensive backups before changes
- Documenting both successes and failures
- Updating documentation promptly when assumptions prove wrong

The cluster is now more stable than at the start of the week, with better monitoring, backups, and documentation. The "critical CSI bug" turned out to be a blessing in disguise, forcing us to improve many aspects of the cluster.

---

**Prepared by**: AI Team (Claude)  
**Date**: June 14, 2025  
**Next Review**: Start of Week 5