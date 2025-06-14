# DevOps Team Session Handoff - K3s Homelab Cluster

## Session Summary (June 14, 2025)
The cluster is now **fully operational** with all critical issues resolved. What was initially diagnosed as a K3s v1.32.5 CSI driver bug turned out to be a k3s1 networking failure. HTTPS/TLS is working, backups are configured to both local MinIO and offsite B2, and comprehensive documentation has been updated.

## Team Collaboration Pattern
**Recommended**: Use zen MCP tools for complex analysis and decision-making:
- `mcp__zen__thinkdeep` - Architecture decisions and complex problem solving
- `mcp__zen__codereview` - Review all changes before applying
- `mcp__zen__debug` - Troubleshoot issues with full context
- `mcp__zen__precommit` - Validate all Git commits

## START HERE: Essential Reading Order
1. **[CLUSTER-SETUP.md](./CLUSTER-SETUP.md)** - Complete cluster overview with current state
   - Pay special attention to the AAR Log section for incident history
   - Review the Storage Architecture and GPU Architecture tables
   - Check Active Work Items for current priorities

2. **[docs/next-session-tasks.md](./docs/next-session-tasks.md)** - Immediate action items
   - Organized by priority (P0/P1/P2)
   - Contains specific checklists for each task

3. **[docs/week4-tls-gateway-summary.md](./docs/week4-tls-gateway-summary.md)** - Recent work summary
   - Documents all fixes applied this week
   - Lists remaining issues and decisions needed

## Current Priorities (P0 - Must Fix)
1. **Flux Reconciliation Issues**
   ```bash
   flux get all -A | grep -v "True"
   # Shows: Authentik secret missing, Intel GPU CRDs not installed
   ```

2. **Root Cause Analysis - k3s1 Network Failure**
   - Incident occurred ~2025-06-13 16:00 UTC
   - Need to analyze logs to prevent recurrence

## Quick Verification Commands
```bash
# Cluster health check
kubectl get nodes -o wide
kubectl get pods -A | grep -v Running

# GitOps status
flux get all -A | grep -v "True"

# Storage verification
kubectl get pvc -A | grep -v Bound
kubectl get nodes.longhorn.io -n longhorn-system

# Service access test
curl -k https://longhorn.fletcherlabs.net
```

## Key Information
- **SOPS Age Key**: `~/.config/sops/age/keys.txt` (CRITICAL - must be backed up!)
- **GitHub Repo**: https://github.com/sudoflux/flux-k3s
- **Services**: All accessible at https://*.fletcherlabs.net
- **GPU**: Tesla T4 uses time-slicing (no memory isolation)
- **Backups**: Velero → MinIO (local) + B2 (offsite) daily

## What's Working
✅ All nodes operational  
✅ Longhorn storage on all nodes  
✅ HTTPS/TLS with valid certificates  
✅ Gateway API with ALPN/app-protocol  
✅ Velero backups (local + offsite)  
✅ All media and AI services  

## Known Issues
🟡 Flux: 2 reconciliation failures  
🟡 Monitoring: Using ephemeral storage  
🟡 Architecture: No HA (single control plane)  
🟡 Security: Authentik needs configuration  

## Documentation Map
- **Troubleshooting**: [storage-and-node-health-troubleshooting.md](./docs/storage-and-node-health-troubleshooting.md)
- **Storage Plans**: [storage-migration-plan.md](./docs/storage-migration-plan.md)
- **Future GPU**: [wsl2-gpu-node-plan.md](./docs/wsl2-gpu-node-plan.md)
- **Emergency**: [EMERGENCY-DOWNGRADE-COMMANDS.md](./EMERGENCY-DOWNGRADE-COMMANDS.md)

---
**Last Updated**: June 14, 2025  
**Updated By**: AI Team (Claude)  
**Key Achievement**: Resolved critical "CSI bug" (was actually network issue)