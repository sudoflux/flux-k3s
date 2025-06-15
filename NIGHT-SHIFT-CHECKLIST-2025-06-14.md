# Night Shift Checklist - June 14, 2025

## Critical Monitoring Points

### 1. Longhorn CSI Health Check
```bash
# Monitor K3s node logs for CSI issues
sudo journalctl -u k3s -f | grep -E "longhorn|csi|kubelet"

# Verify all nodes still have correct kubelet path
for node in k3s-master1 k3s1 k3s2 k3s3; do
  echo "=== $node ==="
  ssh $node "grep 'root-dir' /etc/rancher/k3s/config.yaml"
done
```

### 2. Media Apps Health Verification
```bash
# Check all media apps are running
kubectl get pods -n media

# Verify Recyclarr (last migrated) is functioning
kubectl logs -n media deployment/recyclarr --tail=50

# Check Whisparr on Optane performance
kubectl exec -n media deployment/whisparr -- df -h /config
```

### 3. Storage Health
```bash
# Longhorn system health
kubectl get pods -n longhorn-system | grep -v Running

# Check for any stuck volumes
kubectl get volumes.longhorn.io -n longhorn-system | grep -v attached | grep -v detached

# Verify no orphaned PVCs
kubectl get pvc --all-namespaces | grep -E "Pending|Lost"
```

## Pending Tasks for Night Shift

1. **DO NOT DEPLOY** monitoring stack PVCs yet - waiting for day shift review
2. Monitor existing applications for stability
3. Document any anomalies in this file

## Emergency Rollback Procedures

### If Longhorn CSI Issues Occur:
1. Check the issue on affected node
2. Verify `/etc/rancher/k3s/config.yaml` still has kubelet-arg section
3. If missing, restore from backup: `/etc/rancher/k3s/config.yaml.backup`
4. Restart K3s: `sudo systemctl restart k3s`

### If Media App Issues:
1. Check pod logs: `kubectl logs -n media <pod-name>`
2. Old NFS PVCs still exist as fallback (not deleted yet)
3. Can revert deployment to use old PVC if critical

## What Was Accomplished Today

✅ Fixed Longhorn CSI mount issue across all nodes
✅ Migrated all media apps to Longhorn storage
✅ Optimized Whisparr with Intel Optane storage
✅ Cleaned up all test resources
✅ Created monitoring PVCs (ready for deployment)

## Known Issues

- Media apps lost configuration during migration - need reconfiguration
- Monitoring stack still using old PVCs - deployment pending  
- Old NFS PVCs still exist - cleanup pending after stability confirmation
- Old completed pods were cleaned up during handoff preparation

## Contact

If critical issues arise, escalate to day shift team with details in Slack

---
**Last Updated**: June 14, 2025 20:30 UTC
**Next Review**: Start of next day shift