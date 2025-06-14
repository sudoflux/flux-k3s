# ADR-002: Flux Reconciliation Fixes and Infrastructure Improvements

## Status
Accepted

## Context
On June 14, 2025, the cluster had two critical Flux reconciliation failures that were preventing proper GitOps operations:
1. Authentik HelmRelease failing due to missing variable substitution configuration
2. Intel GPU Plugin HelmRelease failing due to missing CRDs

Additionally, we identified:
- A security vulnerability with a hardcoded secret in open-webui
- The monitoring stack using ephemeral storage, risking data loss

## Decision

### 1. Fixed Flux Variable Substitution
- Added `postBuild.substituteFrom` configuration to the main `apps` Kustomization
- Added the same configuration to the `auth` Kustomization with proper namespace reference
- Enabled SOPS decryption on the apps Kustomization to support encrypted secrets

### 2. Removed Intel GPU Plugin
- Determined that no Intel GPUs were in use (only NVIDIA on k3s3)
- Removed the entire Intel GPU plugin infrastructure component
- Cleaned up node labels and dependencies

### 3. Secured Open-WebUI
- Created a SOPS-encrypted secret with a secure random key
- Updated the HelmRelease to reference the secret instead of hardcoded value
- Removed the security vulnerability from version control

### 4. Migrated Monitoring to Persistent Storage
- Changed all monitoring components from `local-path` to `longhorn-replicated`
- Provided 3-way replication for data durability
- Updated documentation to reflect Longhorn now working on k3s3

## Consequences

### Positive
- GitOps reconciliation is now healthy
- Improved security posture with no hardcoded secrets
- Monitoring data now persists through node failures
- Simplified infrastructure by removing unused components

### Negative
- One-time data loss for monitoring stack during migration
- Slightly reduced I/O performance due to network replication

### Neutral
- Intel GPU support removed but can be re-added if needed

## Implementation Details

### Files Modified
1. `/clusters/k3s-home/workloads/cluster-sync.yaml` - Added SOPS and substitution to apps
2. `/clusters/k3s-home/apps/auth-kustomization.yaml` - Fixed dependencies and substitution
3. `/clusters/k3s-home/apps/ai/open-webui/` - Added encrypted secret, updated HelmRelease
4. `/clusters/k3s-home/apps/monitoring/` - Updated storage classes to longhorn-replicated
5. `/clusters/k3s-home/infrastructure/05-intel-gpu-plugin/` - Removed entirely
6. `/docs/k3s3-storage-workaround.md` - Updated to reflect Longhorn working

### Key Learnings
1. Flux Kustomizations need explicit configuration for variable substitution
2. Cross-namespace secret references require namespace specification
3. Removing unused components improves maintainability
4. Persistent storage should be the default for stateful workloads

---
*Date: June 14, 2025*
*Authors: AI DevOps Team (Claude, Gemini 2.5 Pro, o3-mini)*