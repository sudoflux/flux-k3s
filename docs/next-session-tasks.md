# Tasks for Next AI Session

## Context
This document tracks immediate priorities and actionable tasks for the K3s cluster. It is updated after each session to reflect current state and next steps.

**Last Updated**: 2025-06-14 - Post-incident update following k3s1 networking resolution and HTTPS/TLS fixes

## Priority 0 - Critical Issues (GitOps Health)

### 1. Complete Remaining Flux Reconciliations
**Objective:** Fix the two remaining Flux issues to ensure full GitOps control.

**Actionable Checklist:**
- [ ] **Fix Authentik Secret Issue**
  - Error: `could not resolve Secret chart values reference 'authentik/authentik-secret'`
  - Check if secret exists: `kubectl get secret -n authentik authentik-secret`
  - If missing, create from template or documentation
  - Force reconciliation: `flux reconcile hr authentik -n authentik`

- [ ] **Install Intel GPU Plugin CRDs**
  - Error: `no matches for kind "GpuDevicePlugin" in version "deviceplugin.intel.com/v1"`
  - This requires the Intel device plugin CRDs to be installed
  - Check if this is needed (only if using Intel GPUs)
  - If not needed, consider removing the HelmRelease

## Priority 1 - High Priority Tasks

### 1. Root Cause Analysis: k3s1 Network Failure
**Objective:** Prevent recurrence by understanding why k3s1 lost connectivity.

**Actionable Checklist:**
- [ ] **Collect logs from incident timeframe** (approximately 2025-06-13 16:00-18:00 UTC)
  ```bash
  # On k3s1
  sudo journalctl --since "2025-06-13 16:00" --until "2025-06-13 18:00" > /tmp/k3s1-incident.log
  dmesg -T | grep -E "2025-06-13" > /tmp/k3s1-kernel.log
  ```

- [ ] **Check for resource exhaustion**
  - Review CPU/memory metrics from Prometheus during incident
  - Look for OOM killer activity in kernel logs
  - Check disk I/O patterns

- [ ] **Analyze Cilium behavior**
  ```bash
  kubectl logs -n kube-system -l app.kubernetes.io/name=cilium-agent --since-time="2025-06-13T16:00:00Z" | grep k3s1
  ```

- [ ] **Document findings** in AAR format

### 2. Migrate Monitoring Stack to Longhorn
**Objective:** Move from ephemeral local-path to replicated Longhorn storage.

**Current State:**
- Prometheus, Grafana, Loki all using local-path
- Risk of data loss on pod restart

**Migration Steps:**
- [ ] **Create backup of current data**
  ```bash
  velero backup create monitoring-backup --include-namespaces monitoring
  ```

- [ ] **Update HelmRelease storage classes**
  - Prometheus: Change to `longhorn`
  - Grafana: Change to `longhorn`  
  - Loki: Change to `longhorn`

- [ ] **Perform controlled migration**
  - Scale down workloads
  - Delete old PVCs
  - Scale up with new storage
  - Verify data persistence

## Priority 2 - Medium Priority Tasks

### 1. Complete Authentik Configuration
**Objective:** Set up initial authentication system without enabling 2FA.

**Steps:**
- [ ] Fix missing secret issue first (see Priority 0)
- [ ] Access Authentik UI and create admin user
- [ ] Configure OAuth2/OIDC providers
- [ ] Create test application integration
- [ ] Document configuration for team
- [ ] **DO NOT ENABLE 2FA** until all infrastructure stable

### 2. Plan High Availability Improvements
**Current Risks:**
- Single control plane node
- Single storage server (R730)
- No network redundancy

**Research Tasks:**
- [ ] Document requirements for multi-master setup
- [ ] Evaluate distributed storage options
- [ ] Create phased HA implementation plan

## Future Tasks (After Current Priorities)

### Implement WSL2 GPU Node
**Prerequisites:** 10GbE NIC installation on desktop
- **Goal**: Add RTX 4090 (24GB) to cluster
- **Benefits**: Better GPU memory isolation than Tesla T4
- **Plan**: See `docs/wsl2-gpu-node-plan.md`
- **Script**: `docs/setup-wsl-k3s-node.ps1`

## Quick Status Reference

### ✅ What's Working
- All nodes operational with Longhorn storage
- All media and AI services running
- HTTPS/TLS with valid certificates
- Velero backups to MinIO and B2
- Gateway API with proper ALPN/app-protocol support

### 🟡 Known Issues
- Flux: 2 reconciliation failures (Authentik, Intel GPU)
- Monitoring: Using ephemeral storage
- Architecture: No HA for control plane or storage
- Security: Authentik not configured

## Session Handoff Checklist

### Before Ending Session
- [ ] Update this document with completed/new tasks
- [ ] Commit all changes with descriptive messages
- [ ] Run `flux get all -A` and document any issues
- [ ] Update relevant documentation if procedures changed
- [ ] Note any blocking issues for next session

### Key Files to Review
- **Cluster State**: [CLUSTER-SETUP.md](../CLUSTER-SETUP.md)
- **Incident History**: See AAR Log section
- **Troubleshooting**: [storage-and-node-health-troubleshooting.md](storage-and-node-health-troubleshooting.md)
- **Architecture**: Storage tiers, GPU config, network topology in CLUSTER-SETUP.md

## Critical Reminders
- **SOPS Key**: `~/.config/sops/age/keys.txt` - Must be backed up!
- **No 2FA**: Do not enable Authentik 2FA until cluster fully stable
- **Snapshots**: VM snapshots exist for recovery
- **GPU Note**: Tesla T4 uses time-slicing (no memory isolation)