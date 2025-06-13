# Week 3: Observability Stack Implementation Summary

## Overview
Successfully deployed a comprehensive observability stack for the K3s homelab cluster, providing metrics, logs, and GPU monitoring capabilities.

## Components Deployed

### 1. kube-prometheus-stack (v65.5.1)
- **Prometheus**: Time-series metrics database
  - Storage: local-path (50Gi) for optimal TSDB performance
  - Retention: 30 days
  - Resource limits: 4 CPU, 10Gi memory
- **Grafana**: Visualization and dashboarding
  - Storage: longhorn-sas-ssd (10Gi) for persistence
  - Pre-configured dashboards for node metrics, Kubernetes resources, and GPU monitoring
  - Accessible via HTTPRoute at grafana.fletcherlabs.net
  - Admin credentials stored in SOPS-encrypted secret
- **Alertmanager**: Alert routing and management
  - Storage: longhorn-sas-ssd (5Gi)
  - Basic routing configured
- **Node Exporter**: System metrics from all nodes
- **Kube State Metrics**: Kubernetes resource metrics

### 2. NVIDIA DCGM Exporter (v3.1.5)
- Deployed specifically on k3s3 (GPU node)
- Monitors RTX 4090 metrics:
  - GPU utilization
  - Memory usage
  - Temperature
  - Power consumption
- ServiceMonitor configured for Prometheus scraping
- Dashboard pre-configured in Grafana

### 3. Loki (v5.42.0)
- Single binary deployment for homelab efficiency
- Filesystem storage with Longhorn (10Gi)
- 7-day log retention
- Integrated with Grafana as data source
- Resource optimized: 500m CPU, 512Mi memory limits

## Architecture Decisions

### Storage Strategy
- **Prometheus TSDB**: local-path for high IOPS requirements
- **Grafana & Alertmanager**: longhorn-sas-ssd for durability
- **Loki**: longhorn-sas-ssd with filesystem backend

### Resource Allocation
All components configured with conservative resource requests suitable for homelab:
- Prevents resource starvation
- Allows for burst capacity
- Monitored via self-metrics for optimization

### GitOps Integration
- All deployments via HelmRelease resources
- SOPS encryption for sensitive data
- Flux CD manages reconciliation
- Proper dependencies configured

## Access Points
- Grafana UI: https://grafana.fletcherlabs.net
- Prometheus: Internal service (kube-prometheus-stack-prometheus:9090)
- Loki: Internal service (loki:3100)
- Alertmanager: Internal service (kube-prometheus-stack-alertmanager:9093)

## Next Steps
1. Monitor actual resource usage and adjust limits
2. Configure alerting rules for critical conditions
3. Create custom homelab dashboard
4. Consider adding:
   - Promtail for log collection
   - Additional exporters (blackbox, SNMP)
   - Alert notification channels

## Migration Notes
- All monitoring data stored on persistent volumes
- Grafana dashboards and data sources preserved across restarts
- Consider future migration to object storage (MinIO) for Loki if log volume increases