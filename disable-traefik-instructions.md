# Disable K3s Traefik Addon

## Steps to disable Traefik in K3s

### 1. Update K3s server configuration on the master node (k3s-master1)

SSH into the master node and update the K3s configuration:

```bash
# SSH to master node
ssh josh@192.168.10.30

# Backup current config
sudo cp /etc/rancher/k3s/config.yaml /etc/rancher/k3s/config.yaml.backup-$(date +%Y%m%d-%H%M%S)

# Edit the config to add disable-helm-controller or disable specific charts
sudo nano /etc/rancher/k3s/config.yaml
```

Add the following to the config.yaml:

```yaml
# Disable Traefik ingress controller
disable:
  - traefik

# Keep existing configuration
kube-apiserver-arg:
  - "feature-gates=AuthorizeNodeWithSelectors=false"
```

### 2. Alternative: Modify K3s systemd service

If you prefer to use command-line arguments, update the systemd service:

```bash
sudo nano /etc/systemd/system/k3s.service
```

Update the ExecStart line to include `--disable=traefik`:

```
ExecStart=/usr/local/bin/k3s \
    server \
    '--flannel-backend=none' \
    '--disable-network-policy' \
    --disable=servicelb \
    --disable=traefik
```

### 3. Restart K3s service

```bash
# Reload systemd if you modified the service file
sudo systemctl daemon-reload

# Restart K3s
sudo systemctl restart k3s

# Check status
sudo systemctl status k3s
```

### 4. Clean up existing Traefik resources

```bash
# Delete HelmChart resources
kubectl delete helmchart traefik -n kube-system
kubectl delete helmchart traefik-crd -n kube-system

# Delete the failing pod
kubectl delete pod -n kube-system -l name=helm-install-traefik

# Check for any remaining Traefik resources
kubectl get all -A | grep traefik
```

### 5. Verify Cilium Gateway API is still working

```bash
# Check Gateway
kubectl get gateway -A

# Check GatewayClass
kubectl get gatewayclass

# Check HTTPRoutes
kubectl get httproute -A
```

## Why this is safe

1. You're already using Cilium Gateway API as your ingress solution
2. Traefik is currently failing to install anyway
3. The K3s service already has servicelb disabled
4. This will reduce log noise and resource usage

## Notes

- The `--disable=traefik` flag prevents K3s from deploying the Traefik ingress controller
- This won't affect your existing Cilium Gateway API setup
- If you ever need Traefik back, just remove the disable flag and restart K3s