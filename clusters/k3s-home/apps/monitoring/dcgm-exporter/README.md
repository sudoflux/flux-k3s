# DCGM Exporter Configuration

## Overview
This directory contains the Flux configuration for deploying NVIDIA DCGM Exporter to monitor GPU metrics in the Kubernetes cluster.

## Health Probe Configuration
The DCGM exporter has been configured with proper health probes to prevent failures during startup:

### Liveness Probe
- **Path**: `/health` on port 9400
- **Initial Delay**: 60 seconds (allows GPU initialization)
- **Period**: 30 seconds
- **Timeout**: 10 seconds
- **Failure Threshold**: 3 consecutive failures before restart

### Readiness Probe
- **Path**: `/health` on port 9400
- **Initial Delay**: 45 seconds (allows DCGM to fully initialize)
- **Period**: 15 seconds
- **Timeout**: 5 seconds
- **Failure Threshold**: 2 consecutive failures before marking unready

## Security Improvements
- Removed `privileged: true` from security context
- Retained only necessary capabilities (SYS_ADMIN)
- Uses NVIDIA runtime class for proper GPU access

## Resource Limits
- Increased CPU limit from 200m to 500m to handle initialization load
- Memory limits remain at 256Mi

## Deployment
The exporter is configured to run only on node `k3s3` which has NVIDIA GPUs available.

## Metrics
- Metrics are exposed on port 9400 at `/metrics`
- ServiceMonitor is configured for Prometheus scraping every 15 seconds

## Troubleshooting
If health probes continue to fail:
1. Check GPU driver installation on node k3s3
2. Verify NVIDIA runtime is properly configured
3. Check pod logs: `kubectl logs -n monitoring -l app.kubernetes.io/name=dcgm-exporter`
4. Ensure DCGM is properly installed on the host node