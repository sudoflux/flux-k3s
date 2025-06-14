# Flux GitOps Architecture

## Repository Structure

```
flux-k3s/
├── clusters/k3s-home/
│   ├── workloads/
│   │   └── cluster-sync.yaml    # Dependency ordering
│   ├── infrastructure/
│   │   ├── 00-gateway-api/      # CRDs
│   │   ├── 01-cilium/           # CNI
│   │   ├── 02-cert-manager/     # Certificates
│   │   ├── 04-node-feature-discovery/  # Hardware detection
│   │   ├── 05-intel-gpu-plugin/       # GPU support
│   │   └── 06-nvidia-gpu-plugin/      # GPU support
│   ├── infrastructure-runtime/
│   │   └── 04-gateway/          # Gateway configuration
│   └── apps/
│       ├── sources/             # Helm repositories
│       ├── auth/                # Authentik
│       ├── media/               # Plex, Jellyfin, etc.
│       ├── monitoring/          # Prometheus, Grafana
│       └── longhorn/            # Storage (not actively used)
```

## Dependency Management

### Layer Strategy (from cluster-sync.yaml)

1. **Sources** - Helm repositories
2. **CRDs** - Gateway API definitions
3. **cert-manager** - Must be ready before services
4. **Cilium** - CNI must be operational
5. **NFD** - Required for GPU plugins
6. **GPU Plugins** - Depend on NFD
7. **Runtime Infrastructure** - Depends on GPU plugins
8. **Applications** - Final layer

### Key Dependencies

```yaml
# Example: GPU plugin requires NFD
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata: 
  name: infra-intel-gpu
  namespace: flux-system
spec:
  dependsOn: 
    - name: infra-nfd  # Must wait for NFD
```

## SOPS Encryption

### Encrypted Secrets
- Used for: API tokens, passwords, certificates
- Decryption key: `sops-age` secret in flux-system namespace

### Kustomization with SOPS
```yaml
spec:
  decryption:
    provider: sops
    secretRef:
      name: sops-age
```

## Common Patterns

### Application Deployment

1. **Helm Release + HTTPRoute**
   ```
   apps/myapp/
   ├── helmrelease.yaml
   ├── httproute.yaml
   ├── kustomization.yaml
   └── values.yaml (if needed)
   ```

2. **Kustomization Structure**
   ```yaml
   apiVersion: kustomize.config.k8s.io/v1beta1
   kind: Kustomization
   resources:
     - helmrelease.yaml
     - httproute.yaml
   ```

## Troubleshooting Flux

### Check Reconciliation Status
```bash
flux get kustomizations --all-namespaces
flux get helmreleases --all-namespaces
```

### Force Reconciliation
```bash
flux reconcile kustomization <name> -n flux-system --with-source
flux reconcile hr <name> -n <namespace>
```

### Common Issues

1. **Dependency Not Ready**
   - Check dependent kustomization status
   - Force reconcile the dependency first

2. **SOPS Decryption Failed**
   - Verify sops-age secret exists
   - Check age key permissions

3. **Source Not Found**
   - Ensure HelmRepository is defined in sources/
   - Check repository URL and credentials

## Best Practices

1. Always define dependencies explicitly
2. Use SOPS for all sensitive data
3. Test locally with `kubectl kustomize`
4. Keep resource definitions close to their kustomization.yaml
5. Use meaningful commit messages for GitOps history