# Longhorn Analysis - June 13, 2025 k3s1 Network Incident

## Summary

During the June 13, 2025 network incident on k3s1, Longhorn storage was **not impacted** because no Longhorn volumes were provisioned at the time.

## Current State

### Longhorn Deployment Status
- Longhorn is fully deployed and operational
- All Longhorn system pods are running across 3 nodes (k3s1, k3s2, k3s3)
- Multiple storage classes are configured but unused

### Storage Classes
```
longhorn                  - Basic Longhorn storage
longhorn-nvme (default)   - NVMe-backed storage
longhorn-optane          - Intel Optane storage  
longhorn-replicated      - Multi-replica storage
longhorn-sas-ssd         - SAS SSD storage
```

### Volume Status
- **0 Longhorn persistent volumes (PVs) currently exist**
- No PVCs are using Longhorn storage classes
- The cluster appears to be using local-path as the actual default storage

## Impact Analysis

Since no Longhorn volumes existed during the incident:
1. No data availability issues occurred
2. No replica rebuilding was needed
3. No volume detachment/reattachment issues
4. The CSI driver errors were unrelated to actual storage operations

## Recommendations

1. **Clarify Storage Strategy**: Determine whether Longhorn should be the primary storage solution
2. **Update Default StorageClass**: If Longhorn is preferred, remove the duplicate default annotation
3. **Test Longhorn**: Create test volumes to ensure Longhorn functions correctly
4. **Monitor Usage**: Set up alerts for when Longhorn volumes are created

## Notes

The initial diagnosis of "CSI driver bug" was incorrect. The actual issue was:
- k3s1 network interface rename (tmpe2695 → eth0) 
- This caused node connectivity loss
- CSI errors were a symptom, not the cause
- No storage operations were impacted due to lack of active volumes