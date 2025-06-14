# AI Team Onboarding Guide

## Welcome to the K3s Homelab Cluster

This guide helps new AI team members quickly understand the cluster state, critical issues, and how to be productive from day one.

## 🟢 Current Cluster State - Read First

### System Status
**The cluster is stable and operational** - All services running normally
- **Recent incident resolved**: k3s1 networking failure (initially misdiagnosed as CSI issue)
- **Key lesson**: Node-level issues can create misleading cluster-wide symptoms
- **Always verify basic connectivity first** before assuming component bugs
- **See the AAR**: [CLUSTER-SETUP.md](../CLUSTER-SETUP.md#aar-log) for full incident details

### Safety Mechanisms
- **VM Snapshots**: Available for all nodes - use for safe rollback
- **GitOps**: All changes via Flux - can suspend with `flux suspend kustomization --all`
- **SOPS Encryption**: Age key at `~/.config/sops/age/keys.txt` - ensure backed up!

## Quick Start Checklist

### Day 1 - Orientation
- [ ] Read `/home/josh/flux-k3s/CLUSTER-SETUP.md` - comprehensive cluster overview
- [ ] Review `/home/josh/flux-k3s/docs/next-session-tasks.md` - immediate priorities
- [ ] Check cluster status: `kubectl get nodes` and `flux get all -A`
- [ ] Verify access to all services at `https://*.fletcherlabs.net`

### Day 2 - Verify System Health
- [ ] Check all nodes have CSI drivers: `kubectl get csinode`
- [ ] Verify GitOps sync: `flux get all -A | grep -v "True"`
- [ ] Review storage health: `kubectl get pvc -A | grep -v Bound`
- [ ] Check recent events: `kubectl get events -A --sort-by='.lastTimestamp' | head -20`
- [ ] Study troubleshooting guide: `/home/josh/flux-k3s/docs/storage-and-node-health-troubleshooting.md`

### Day 3 - Current Priorities
- [ ] Fix Flux reconciliation issues (Authentik secret, Intel GPU CRDs)
- [ ] Investigate k3s1 network failure root cause
- [ ] Migrate monitoring stack to Longhorn storage
- [ ] Complete Authentik initial configuration (NO 2FA yet!)
- [ ] Review AAR action items in CLUSTER-SETUP.md

## Key Commands Reference

### Cluster Health
```bash
# Node status
kubectl get nodes -o wide
kubectl top nodes

# Pod health
kubectl get pods -A | grep -v Running
kubectl get pods -A | grep -v "1/1\|2/2\|3/3"

# Storage status
kubectl get pvc -A
kubectl get storageclass
```

### GitOps Management
```bash
# Check Flux status
flux get all -A
flux logs --follow

# Force reconciliation
flux reconcile kustomization apps --with-source

# Emergency pause
flux suspend kustomization --all
```

### Troubleshooting
```bash
# Node connectivity check
kubectl run debug --image=busybox --rm -it -- sh
# From inside: ping <service-ip>, curl http://<service>:<port>

# Recent errors
kubectl get events -A --field-selector type=Warning

# Service logs
kubectl logs -n <namespace> deployment/<name> --tail=100

# Storage issues
kubectl describe pvc <name> -n <namespace>
kubectl get volumes.longhorn.io -n longhorn-system
```

## Understanding the Architecture

### Hardware Layout
```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   Dell R730     │     │   Dell R630     │     │ OptiPlex Micro  │
│ (Storage/VMs)   │     │    (k3s3)       │     │  (k3s1, k3s2)  │
│                 │     │                 │     │                 │
│ - k3s-master1   │     │ - GPU: Tesla T4 │     │ - QuickSync     │
│ - NFS Storage   │     │ - 384GB RAM     │     │ - Light compute │
│   └─ NVMe       │     │ - Multi-tier    │     │ - Longhorn ✓    │
│   └─ 30TB HDD  │     │   storage       │     │                 │
└─────────────────┘     └─────────────────┘     └─────────────────┘
```

### Service Categories
1. **Media Stack**: Jellyfin, Plex, *arr apps - all working
2. **AI Stack**: Ollama, Automatic1111 - GPU accelerated on k3s3
3. **Infrastructure**: Monitoring, backups, auth - partially impacted by CSI issue

## Common Tasks

### Checking Service Health
```bash
# Media services
kubectl get pods -n media
kubectl get httproute -n media

# AI services  
kubectl get pods -n ai
nvidia-smi  # on k3s3

# Infrastructure
kubectl get pods -n monitoring
kubectl get pods -n longhorn-system
```

### Working with Storage
```bash
# Current storage usage
kubectl exec -n monitoring prometheus-0 -- df -h
kubectl get pv | grep -E "Bound|Released"

# Test Longhorn
kubectl apply -f /tmp/test-csi-after-fix.yaml
kubectl get pvc test-csi-fix -w
```

### Emergency Procedures
1. **If cluster becomes unstable**: Check `/home/josh/flux-k3s/EMERGENCY-DOWNGRADE-COMMANDS.md`
2. **If need rollback**: Contact team about VM snapshots
3. **If Flux breaks**: `kubectl apply -k /home/josh/flux-k3s/clusters/k3s-home/flux-system/`

## Documentation Map

### Essential Reading Order
1. **This file** - Basic orientation
2. **CLUSTER-SETUP.md** - Complete system overview
3. **next-session-tasks.md** - What to work on
4. **csi-troubleshooting-guide.md** - Fix storage issues

### Reference Documents
- **Storage**: storage-migration-plan.md, k3s3-storage-workaround.md
- **Backups**: velero-offsite-setup.md, backblaze-b2-setup.md
- **Emergency**: EMERGENCY-DOWNGRADE-COMMANDS.md
- **Future**: wsl2-gpu-node-plan.md

### Weekly Summaries
Located in `/home/josh/flux-k3s/docs/`:
- week1-security-summary.md
- week2-storage-backup-summary.md  
- week3-observability-summary.md

## Communication Guidelines

### Working with MCP Tools
The cluster uses `mcp__zen__*` tools for AI collaboration:
- `thinkdeep`: Complex problem solving
- `codereview`: Review changes before applying
- `debug`: Troubleshoot issues with full context
- `precommit`: Validate changes before git commits

### Best Practices
1. **Always test changes** in a test namespace first
2. **Document everything** - future you will thank you
3. **Ask for help** - use MCP tools to collaborate
4. **Verify backups** before major changes
5. **Communicate status** - update tasks and documentation

## Your First Actions

1. **Verify Access**:
   ```bash
   kubectl get nodes
   flux get all -A
   ```

2. **Check Critical Issue**:
   ```bash
   kubectl get csinode k3s3 -o yaml | grep -A10 "spec:"
   ```

3. **Review Immediate Tasks**:
   ```bash
   cat /home/josh/flux-k3s/docs/next-session-tasks.md
   ```

4. **Check Longhorn node status**:
   ```bash
   kubectl get nodes.longhorn.io -n longhorn-system
   ```

4. **Update Your Progress**:
   - Use TodoWrite to track your work
   - Update documentation as you learn
   - Commit findings to help next team

## Current Action Items

1. **P0 - Flux Health**: Fix Authentik secret and Intel GPU CRDs
2. **P1 - Root Cause**: Why did k3s1 lose network connectivity?
3. **P2 - Monitoring**: Migrate from local-path to Longhorn storage
4. **P3 - Security**: Configure Authentik (without 2FA initially)
5. **Future**: Add WSL2 GPU node after 10GbE NIC installation

## Getting Help

### Internal Resources
- All documentation in `/home/josh/flux-k3s/docs/`
- Test manifests in `/tmp/test-*.yaml`
- Migration tools in `apps/media/bazarr/migration/`

### External Resources
- K3s Docs: https://docs.k3s.io/
- Longhorn Docs: https://longhorn.io/docs/
- Flux Docs: https://fluxcd.io/docs/

### Emergency Contacts
- VM snapshots available - ask before major changes
- GitHub repo: https://github.com/sudoflux/flux-k3s
- Slack/Discord channels for team communication

---

**Welcome aboard!** You're joining at an interesting time with some challenges to solve. The cluster is production-ready for most services, but the storage layer needs attention. Your fresh perspective could be exactly what we need to solve the CSI issue.

**Remember**: It's okay to ask questions, test thoroughly, and take breaks. Complex systems require patience and methodical approaches.

**Last Updated**: 2025-06-14  
**Updated By**: AI Team (Claude) - Post-incident documentation update  
**Key Changes**: Removed incorrect CSI bug information, updated with actual cluster state