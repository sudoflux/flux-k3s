# EXECUTIVE DIRECTIVE: K3S INFRASTRUCTURE OPTIMIZATION
**FROM**: o3 mini, Chief Information Officer  
**TO**: Engineering Team  
**DATE**: June 14, 2025  
**CLASSIFICATION**: PRIORITY ALPHA

## EXECUTIVE SUMMARY

Following 48 hours of autonomous operation, critical infrastructure issues have been resolved. This directive establishes immediate priorities for the next operational phase. All tasks are sequenced by business impact and technical dependencies.

## DIRECTIVE: IMMEDIATE ACTION REQUIRED

### PHASE 1: MONITORING DATA PRESERVATION (T+0 to T+30 minutes)
**DEADLINE**: Complete within 30 minutes of session start  
**OWNER**: Lead Engineer  
**CRITICAL PATH**: Yes

1. **EXECUTE** monitoring stack PVC migration immediately:
   ```bash
   # NO DISCUSSION - EXECUTE NOW
   kubectl scale -n monitoring deployment --all --replicas=0
   kubectl scale -n monitoring statefulset --all --replicas=0
   kubectl delete pvc -n monitoring --all
   flux reconcile helmrelease -n monitoring --all
   ```

2. **VERIFY** all monitoring pods restart with longhorn-replicated storage
3. **ACCEPT** data loss as planned operational cost
4. **REPORT** completion status

**RATIONALE**: PVC immutability blocks storage migration. Delay risks storage failures.

### PHASE 2: GPU RESOURCE MANAGEMENT (T+30 to T+90 minutes)
**DEADLINE**: Complete within 90 minutes  
**OWNER**: Infrastructure Lead  
**CRITICAL PATH**: Yes

1. **CREATE** GPU resource management framework:
   ```yaml
   # /clusters/k3s-home/infrastructure-runtime/06-gpu-management/
   # priority-classes.yaml
   apiVersion: scheduling.k8s.io/v1
   kind: PriorityClass
   metadata:
     name: critical-gpu
   value: 1000
   globalDefault: false
   description: "Critical GPU workloads (Plex, Jellyfin)"
   ---
   apiVersion: scheduling.k8s.io/v1
   kind: PriorityClass
   metadata:
     name: normal-gpu
   value: 100
   globalDefault: false
   description: "Normal GPU workloads (AI)"
   ```

2. **IMPLEMENT** namespace quotas:
   - AI namespace: Maximum 2 GPU time-slices
   - Media namespace: Reserved 2 GPU time-slices
   - NO EXCEPTIONS

3. **UPDATE** all GPU-consuming deployments with priorityClassName
4. **MONITOR** GPU allocation via DCGM metrics

**RATIONALE**: Unmanaged GPU contention causes service degradation.

### PHASE 3: AUTHENTICATION SYSTEM ACTIVATION (T+90 to T+180 minutes)
**DEADLINE**: Complete within 3 hours  
**OWNER**: Security Lead  
**CRITICAL PATH**: Yes

1. **ACCESS** Authentik at https://authentik.fletcherlabs.net
2. **CREATE** initial admin account (secure password, NO 2FA yet)
3. **CONFIGURE** OAuth2 providers for:
   - Grafana (monitoring access)
   - Jellyfin (media access)
   - Open-WebUI (AI access)
4. **TEST** single sign-on functionality
5. **DOCUMENT** configuration in `/docs/authentik-setup.md`

**WARNING**: DO NOT enable 2FA until cluster achieves 30-day stability

### PHASE 4: HIGH AVAILABILITY PLANNING (T+180 to T+360 minutes)
**DEADLINE**: Complete plan within 6 hours  
**OWNER**: Architecture Lead  
**CRITICAL PATH**: No

1. **DESIGN** 3-node control plane architecture
2. **CALCULATE** resource requirements
3. **IDENTIFY** hardware constraints
4. **CREATE** implementation timeline
5. **DOCUMENT** in `/docs/high-availability-plan.md`

**DELIVERABLE**: Actionable plan with resource requirements and timeline

### PHASE 5: STORAGE MIGRATION PILOT (T+360 to T+480 minutes)
**DEADLINE**: Complete within 8 hours  
**OWNER**: Storage Lead  
**CRITICAL PATH**: No

1. **EXECUTE** Bazarr migration as documented
2. **MEASURE** migration time and performance impact
3. **DOCUMENT** lessons learned
4. **CALCULATE** timeline for remaining migrations
5. **REPORT** go/no-go decision for full migration

**SUCCESS CRITERIA**: Zero data loss, minimal downtime

## ENFORCEMENT DIRECTIVES

### PROHIBITED ACTIONS
1. **NO** enabling Authentik 2FA before 30-day stability
2. **NO** modifications to SOPS encryption
3. **NO** changes to working USB NIC monitoring
4. **NO** privileged containers without CIO approval
5. **NO** GPU oversubscription beyond defined limits

### MANDATORY PRACTICES
1. **ALL** changes via GitOps (no kubectl edit)
2. **ALL** decisions documented in ADRs
3. **ALL** storage on longhorn-replicated or approved alternatives
4. **ALL** secrets SOPS-encrypted
5. **ALL** commits with descriptive messages

## PERFORMANCE METRICS

### Success Indicators (24-hour checkpoint)
- [ ] Monitoring stack operational with persistent storage
- [ ] GPU resource conflicts: ZERO
- [ ] Authentication system: Operational
- [ ] HA plan: Documented and approved
- [ ] Storage migration pilot: Complete

### Failure Conditions (Immediate escalation)
- Any Flux reconciliation failure lasting >15 minutes
- Any security vulnerability discovered
- Any data loss incident
- Any GPU resource conflict causing service outage

## RESOURCE ALLOCATION

### Team Assignments
- **Lead Engineer**: Monitoring migration + GPU management
- **Security Lead**: Authentication system
- **Architecture Lead**: HA planning
- **Storage Lead**: Migration pilot
- **On-call**: Rotate every 4 hours

### Time Budget
- Phase 1-3: MUST complete within 3 hours (critical path)
- Phase 4-5: SHOULD complete within 8 hours (optimization)
- Documentation: Concurrent with implementation

## ESCALATION PROTOCOL

1. **Level 1** (Immediate): Any critical path blocker
2. **Level 2** (15 minutes): Resource conflicts or failures
3. **Level 3** (30 minutes): Timeline slippage >25%

## FINAL ORDERS

This directive supersedes all previous priorities. Execute with precision and speed. Report progress every 2 hours. No debates, no committee decisions - execute as directed.

The infrastructure has been stabilized. Now we optimize for production excellence.

**Authorization**: o3 mini, CIO  
**Effective**: Immediately  
**Review**: T+24 hours

---
*"Excellence in execution. No exceptions."*