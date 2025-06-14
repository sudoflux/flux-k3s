# Storage Migration Pilot Report - Bazarr

## Executive Summary
The Bazarr storage migration pilot encountered technical challenges that prevented completion within the allocated timeframe. The pilot revealed critical infrastructure dependencies that must be resolved before proceeding with large-scale storage migrations.

## Pilot Objectives
- Migrate Bazarr config storage from NFS to Longhorn
- Measure migration time and performance impact
- Validate migration procedures for broader rollout

## Issues Encountered

### 1. CSI Driver Registration Problem
- **Error**: `driver name driver.longhorn.io not found in the list of registered CSI drivers`
- **Affected Node**: k3s3
- **Impact**: Unable to mount Longhorn volumes on the node where migration job was scheduled

### 2. Root Cause Analysis
The issue appears to be related to the CSI driver not being properly registered on all nodes, despite Longhorn pods running successfully. This is likely connected to the same infrastructure dependency chain affecting other deployments:
```
infra-nfd → infra-intel-gpu → infra-runtime → various apps
```

## Migration Readiness Assessment

### What's Working
✅ Longhorn storage classes are created and available
✅ PVCs can be provisioned successfully  
✅ Monitoring workloads successfully migrated to Longhorn
✅ Migration procedures and documentation are well-prepared

### What's Not Working
❌ CSI driver registration inconsistent across nodes
❌ Infrastructure dependencies preventing clean deployments
❌ Job scheduling to nodes with CSI issues

## Recommendations

### Immediate Actions
1. **Fix Infrastructure Dependencies**
   - Resolve Node Feature Discovery (NFD) deployment issues
   - This will cascade fix other dependent components
   - Ensure CSI drivers are properly registered on all nodes

2. **Alternative Migration Approach**
   - Use pod-to-pod data copy instead of job-based migration
   - Schedule migration pods with node affinity to working nodes
   - Consider using `kubectl cp` for small config volumes

### Go/No-Go Decision: **NO-GO**

**Rationale**: 
- Infrastructure issues must be resolved before proceeding
- Risk of data loss or extended downtime is elevated
- Current NFS storage is stable and functional

### Revised Timeline
1. **Week 1**: Resolve infrastructure dependencies
2. **Week 2**: Validate CSI functionality across all nodes
3. **Week 3**: Retry Bazarr pilot migration
4. **Week 4-6**: Proceed with remaining application migrations if pilot succeeds

## Lessons Learned

1. **Infrastructure Health**: Storage migrations require fully functional CSI drivers on all nodes
2. **Dependency Management**: Flux dependency chains can create cascading failures
3. **Pilot Value**: The pilot approach successfully identified issues before attempting larger migrations

## Risk Mitigation

### For Future Migrations
1. Pre-validate CSI functionality on target nodes
2. Create node affinity rules for migration jobs
3. Implement pre-flight checks before migration
4. Maintain rollback procedures at each step

### Current State
- Bazarr remains on NFS storage (stable)
- Longhorn PVC created but unused
- No data loss or service disruption occurred

## Next Steps

1. **Priority 1**: Fix infra-nfd deployment to resolve dependency chain
2. **Priority 2**: Validate Longhorn CSI on all nodes
3. **Priority 3**: Develop CSI health check procedures
4. **Priority 4**: Retry pilot after infrastructure stabilization

## Conclusion
While the pilot did not achieve its primary objective of migrating Bazarr to Longhorn storage, it successfully identified critical infrastructure issues that would have caused significant problems in a full-scale migration. The conservative approach of starting with a pilot has proven its value by preventing potential data loss and extended downtime across multiple applications.