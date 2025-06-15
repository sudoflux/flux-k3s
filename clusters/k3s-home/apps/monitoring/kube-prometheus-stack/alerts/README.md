# Monitoring Alerts Configuration

This directory contains custom Prometheus alert rules for comprehensive monitoring of the Kubernetes cluster.

## Alert Categories

### 1. Longhorn Storage Alerts (`longhorn-alerts.yaml`)
- **Volume Health**: Monitors volume robustness and state
- **Space Usage**: Alerts when volumes reach 80% (warning) or 95% (critical) capacity
- **Node Storage**: Monitors storage capacity on Longhorn nodes
- **Disk Health**: Tracks disk usage across the cluster

### 2. Storage and CSI Alerts (`storage-alerts.yaml`)
- **CSI Driver Health**: Monitors CSI driver registration and functionality
- **PVC Provisioning**: Alerts on pending or failed PVC provisioning
- **Volume Attachments**: Tracks failed volume attachments
- **Storage Capacity**: Monitors PV capacity usage

### 3. Velero Backup Alerts (`velero-alerts.yaml`)
- **Backup Failures**: Immediate alerts on backup failures
- **Schedule Monitoring**: Alerts when scheduled backups are missed
- **Restore Operations**: Monitors restore success/failure
- **Repository Health**: Tracks backup repository availability

### 4. Node Alerts (`node-alerts.yaml`)
- **Disk Space**: Warns at 80% usage, critical at 90%
- **Root Filesystem**: Special monitoring for root partition
- **Inode Exhaustion**: Alerts before running out of inodes
- **Resource Pressure**: CPU, memory, and load monitoring

### 5. Kubernetes Alerts (`kubernetes-alerts.yaml`)
- **Pod Restarts**: Detects crash loops and excessive restarts
- **Workload Health**: Monitors deployments, statefulsets, and daemonsets
- **Job Failures**: Tracks failed jobs and suspended cronjobs
- **Critical Pods**: Special monitoring for system-critical pods

### 6. Authentik Alerts (`authentik-alerts.yaml`)
- **Authentication Failures**: Detects high failure rates (possible attacks)
- **System Health**: Monitors Authentik components
- **Certificate Expiry**: Warns before certificates expire
- **Integration Issues**: LDAP sync and OAuth provider monitoring

## Severity Levels

- **Critical**: Immediate action required, potential service impact
- **Warning**: Attention needed, but not immediately impacting service
- **Info**: Informational alerts for tracking

## Alert Routing

Alerts are routed based on severity and component:

1. **Critical Alerts**: Immediate notification with 1-hour repeat interval
2. **Storage Alerts**: Routed to storage team
3. **Backup Alerts**: Routed to backup team  
4. **Security Alerts**: Routed to security team with high priority

## Testing Alerts

### 1. Verify PrometheusRule Creation
```bash
kubectl get prometheusrules -n monitoring
```

### 2. Check if Prometheus Discovered the Rules
```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# Visit http://localhost:9090/rules
```

### 3. Test Specific Alerts

#### Test Volume Space Alert
```bash
# Create a test PVC and fill it
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-alert-pvc
  namespace: default
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: longhorn-nvme
  resources:
    requests:
      storage: 1Gi
---
apiVersion: v1
kind: Pod
metadata:
  name: test-alert-pod
  namespace: default
spec:
  containers:
  - name: test
    image: busybox
    command: ["sh", "-c", "dd if=/dev/zero of=/data/testfile bs=1M count=900"]
    volumeMounts:
    - name: test-volume
      mountPath: /data
  volumes:
  - name: test-volume
    persistentVolumeClaim:
      claimName: test-alert-pvc
EOF
```

#### Test Pod Restart Alert
```bash
kubectl create deployment test-crashloop --image=busybox -- sh -c "exit 1"
```

### 4. View Active Alerts
```bash
# Port-forward to Alertmanager
kubectl port-forward -n monitoring svc/kube-prometheus-stack-alertmanager 9093:9093
# Visit http://localhost:9093
```

## Customizing Alerts

### Modify Alert Thresholds
Edit the relevant alert file and adjust the `expr` field:
```yaml
expr: (longhorn_volume_actual_size_bytes / longhorn_volume_capacity_bytes) * 100 > 80
```

### Add New Notification Channels
Edit `alertmanager-config.yaml` to add new receivers:
```yaml
receivers:
- name: 'slack'
  slack_configs:
  - api_url: '${SLACK_WEBHOOK_URL}'
    channel: '#alerts'
```

### Disable Specific Alerts
Add an inhibition rule or route to null receiver in `alertmanager-config.yaml`.

## Maintenance

1. **Regular Review**: Review fired alerts weekly to tune thresholds
2. **Update Runbooks**: Keep runbook URLs updated with solutions
3. **Test Alerts**: Periodically test critical alerts remain functional
4. **Clean Up**: Remove test resources after testing

## Troubleshooting

### Alerts Not Firing
1. Check PrometheusRule is loaded: `kubectl describe prometheusrule <name> -n monitoring`
2. Verify metrics exist: Query Prometheus for the metrics used in expressions
3. Check Prometheus logs: `kubectl logs -n monitoring prometheus-kube-prometheus-stack-prometheus-0`

### Too Many Alerts
1. Adjust thresholds in the alert expressions
2. Add inhibition rules for cascading failures
3. Use `for` duration to reduce flapping

### Alertmanager Not Sending Notifications
1. Check Alertmanager config: `kubectl logs -n monitoring alertmanager-kube-prometheus-stack-alertmanager-0`
2. Verify receiver configuration (SMTP, webhooks, etc.)
3. Test with manual alert: Use Prometheus UI to send test alert