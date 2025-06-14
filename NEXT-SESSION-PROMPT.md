# DevOps Team Session Handoff - K3s Homelab Cluster

## Session Summary (June 14, 2025 - Updated)
The cluster remains **fully operational** with all critical issues resolved. Major accomplishments:
- Identified and fixed root cause of k3s1 network failure (systemd-networkd CNI interference)
- Resolved all Flux reconciliation issues (Authentik, GPU plugins)
- Deployed Cilium Hubble UI for network observability
- Discovered and documented that cluster uses Gateway API, not nginx ingress

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

## Current Priorities (P0 - High Priority)
1. **GPU Resource Management**
   - Document VRAM usage per service in `/docs/gpu-usage.md`
   - Implement PriorityClass for critical GPU workloads (Plex, Frigate)
   - Configure ResourceQuota per namespace for GPU access control
   - Validate Tesla T4 time-slicing configuration

2. **Infrastructure Hardening**
   - Activate USB NIC monitoring systemd service
   - Migrate monitoring to persistent storage (currently ephemeral)
   - Review Gateway API authentication patterns

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
✅ All nodes operational with network protection  
✅ Longhorn storage deployed (but 0 volumes - evaluate usage)  
✅ HTTPS/TLS with valid certificates  
✅ Gateway API (Cilium) - NO nginx ingress  
✅ Velero backups (local + offsite)  
✅ All media and AI services  
✅ Flux reconciliation healthy  
✅ Cilium Hubble UI for network observability  

## Architecture Notes
⚠️ **NO nginx ingress controller** - Use HTTPRoute only  
⚠️ k3s1/k3s2 use USB 2.5GbE NICs (monitor stability)  
⚠️ Gateway: main-gateway at 192.168.10.224  
⚠️ Single control plane (HA planning needed)  

## Documentation Map
### New Critical Docs (READ THESE)
- **Network Architecture**: [network-architecture.md](./docs/network-architecture.md)
- **Gateway API Guide**: [gateway-api-ingress-guide.md](./docs/gateway-api-ingress-guide.md)
- **GitOps Architecture**: [flux-gitops-architecture.md](./docs/flux-gitops-architecture.md)
- **USB NIC Monitoring**: [usb-nic-monitoring.md](./docs/usb-nic-monitoring.md)
- **ADR-001**: [systemd-networkd fix](./docs/adr/001-systemd-networkd-cni-protection.md)

### Existing Docs
- **Troubleshooting**: [storage-and-node-health-troubleshooting.md](./docs/storage-and-node-health-troubleshooting.md)
- **Storage Plans**: [storage-migration-plan.md](./docs/storage-migration-plan.md)
- **Future GPU**: [wsl2-gpu-node-plan.md](./docs/wsl2-gpu-node-plan.md)
- **Emergency**: [EMERGENCY-DOWNGRADE-COMMANDS.md](./EMERGENCY-DOWNGRADE-COMMANDS.md)

---
**Last Updated**: June 14, 2025 (Evening Session)  
**Updated By**: AI Team (Claude with o3-mini as CIO)  
**Key Achievements**: 
- Fixed k3s1 network root cause (systemd-networkd)
- Resolved all Flux reconciliation issues
- Deployed Hubble network observability
- Documented Gateway API architecture