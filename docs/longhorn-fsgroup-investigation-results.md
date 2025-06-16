# Longhorn fsGroup Investigation Results - June 16, 2025

## Executive Summary
After extensive investigation, the fsGroup issue is confirmed to be a bug in Longhorn v1.6.2 that cannot be resolved through configuration changes or workarounds. The only solution is to upgrade Longhorn.

## Investigation Findings

### 1. Directory Structure Analysis
- `/var/lib/kubelet` directories exist on all nodes (k3s1, k3s2, k3s3)
- These directories are hard-linked to `/var/lib/rancher/k3s/agent/kubelet/` (same inodes)
- Pod directories are synchronized between both paths

### 2. Root Cause Identified
The issue is a **race condition** in Longhorn v1.6.2:
- When `fsGroup` is specified, kubelet tries to apply permissions to the mount path
- The CSI driver hasn't created the `mount` subdirectory yet
- This causes: `applyFSGroup failed: lstat .../mount: no such file or directory`

### 3. Proof of Concept
- Pods WITHOUT fsGroup: Mount successfully, `mount` directory is created
- Pods WITH fsGroup: Fail to mount, `mount` directory never gets created
- The CSI driver reports success in logs but the mount isn't actually created

### 4. Why Workarounds Don't Work
- **K3s Configuration**: Directories are already linked, changing kubelet path won't help
- **Symlinks**: Already effectively in place via hard links
- **Bind Mounts**: Would hide existing content and not solve the race condition

## Upgrade Requirements

### Staged Upgrade Path (MANDATORY)
Due to Longhorn's upgrade restrictions, we must follow this path:
1. **v1.6.2 → v1.7.x** (latest 1.7.2)
2. **v1.7.x → v1.8.x** (latest 1.8.2) 
3. **v1.8.x → v1.9.0**

### Risk Assessment
- **High Risk**: No staging environment available
- **Data at Risk**: All Longhorn volumes (config data for apps)
- **Downtime**: Expected 2-4 hours for complete upgrade
- **Rollback**: Limited - only if upgrade fails at validation stage

## Recommendations

### Immediate Actions
1. **Postpone Upgrade**: Given the high risk without staging
2. **Continue with Local-Path**: Keep monitoring stack on local-path storage
3. **Plan for Future**: Set up staging environment first

### Alternative Approach
1. **Accept Current State**: fsGroup apps use local-path, others use Longhorn
2. **Wait for v1.10**: May have better upgrade path or fixes
3. **Focus on Higher Priorities**: HA control plane, storage redundancy

## Decision
Given the investigation results and risk assessment, the safest approach is to:
- Document the issue thoroughly (completed)
- Keep monitoring stack on local-path storage
- Plan Longhorn upgrade for when staging environment is available
- Focus on more critical infrastructure issues (storage SPOF, control plane HA)