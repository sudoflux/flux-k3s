# DevOps Team Onboarding Prompt - K3s Homelab Cluster

## Context
You're joining a K3s homelab cluster that runs media services (Jellyfin, Plex, *arr stack) and AI workloads (Ollama, Automatic1111). The cluster has a **CRITICAL ISSUE**: K3s v1.32.5 has a bug preventing Longhorn CSI driver registration on node k3s3. Multiple fix attempts have failed. VM snapshots are available for safe rollback. All changes must use GitOps via Flux.

## Team Structure & Collaboration Requirements
**IMPORTANT**: Use zen MCP tools continuously throughout all work:
- **o3-mini**: Act as CIO - provide strategic guidance, review all decisions, ensure documentation quality
- **Claude & Gemini 2.5 Pro**: Act as lead engineers - troubleshoot together, review each other's code, validate all changes
- **Collaboration Pattern**: Use `mcp__zen__thinkdeep` for analysis, `mcp__zen__codereview` for changes, `mcp__zen__debug` for troubleshooting, `mcp__zen__precommit` before any commits

## MANDATORY: Read These Documents First (In Order)
1. `/home/josh/flux-k3s/docs/ai-team-onboarding.md` - Quick orientation guide
2. `/home/josh/flux-k3s/CLUSTER-SETUP.md` - Complete cluster overview
3. `/home/josh/flux-k3s/docs/csi-troubleshooting-guide.md` - CSI issue details & failed attempts
4. `/home/josh/flux-k3s/docs/next-session-tasks.md` - Immediate priorities

**Action**: After reading each document, use `mcp__zen__thinkdeep` to share key takeaways with the team.

## Initial Verification (After Reading Docs)
Run these commands and share results via `mcp__zen__debug`:
```bash
# Check CSI registration on k3s3
kubectl get csinode k3s3 -o yaml | grep -A10 "spec:"

# Verify Longhorn pods
kubectl get pods -n longhorn-system -l app=longhorn-csi-plugin -o wide

# Check k3s3 logs (SSH to node)
sudo journalctl -u k3s-agent -n 200 | grep -E "(csi|longhorn|error)"

# Flux status
flux get all -A
```

## Collaboration Workflow
1. **Analyze Together**: Use `mcp__zen__thinkdeep` to discuss findings
2. **Propose Fix**: Use `mcp__zen__codereview` to review configuration changes
3. **Test Safely**: Apply to test namespace first, validate with test PVCs
4. **Validate Changes**: Use `mcp__zen__precommit` before any git commits
5. **Monitor**: Watch CSI registration with:
   ```bash
   watch -n 2 'kubectl get csinode -o custom-columns=NAME:.metadata.name,DRIVERS:.spec.drivers[*].name'
   ```

## Primary Focus: Fix CSI Issue
**Options to explore (in order)**:
1. KUBELET_ROOT_DIR mismatch fix (check paths on k3s3)
2. Longhorn upgrade to v1.9.0
3. K3s downgrade to v1.30.x (last resort)

**Success Criteria**:
- CSINode k3s3 shows `driver.longhorn.io` registered
- Test PVC creates and mounts successfully
- No errors in Longhorn CSI plugin logs

## Critical Reminders
- VM snapshots exist - use for emergency rollback
- All changes via GitOps - no manual edits
- Test in isolated namespace first
- Document every finding and decision
- If stuck, check `/home/josh/flux-k3s/EMERGENCY-DOWNGRADE-COMMANDS.md`

## First Actions Summary
1. Read all 4 documents listed above
2. Share insights via `mcp__zen__thinkdeep` 
3. Run verification commands
4. Collaborate on CSI fix approach using zen MCP tools
5. Test carefully before production changes

**Remember**: Work as a team. o3-mini guides strategy, Claude and Gemini 2.5 Pro collaborate on implementation. Use zen MCP tools for every major decision. The cluster is production - be careful but confident. Good luck!