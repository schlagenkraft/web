# GitOps Deployment Guide for ski.dev

This Kubernetes deployment is designed for GitOps with ArgoCD. Secrets are managed separately for security.

## Architecture

```
k8s/
├── base/                    # Base configurations
│   ├── cert-manager/       # SSL certificate management
│   ├── dns/               # External DNS for Cloudflare
│   ├── deployment.yaml    # Main application
│   ├── service.yaml       # LoadBalancer service
│   └── ingress.yaml       # Ingress with SSL
├── prod/                   # Production overlay
├── staging/               # Staging overlay
├── dev/                   # Development overlay
└── setup-secrets.sh       # Manual secret creation script
```

## Prerequisites

1. **Kubernetes cluster** with:
   - cert-manager installed
   - nginx-ingress controller
   - MetalLB (for LoadBalancer IPs)
   - ArgoCD (for GitOps)

2. **Cloudflare account** with:
   - ski.dev domain
   - API token with Zone:Read and DNS:Edit permissions

3. **GitHub Container Registry** access for pulling images

## Initial Setup

### Step 1: Create Secrets (One-time manual process)

Secrets are NOT stored in Git. Run this before deploying:

```bash
# Set your Cloudflare API token
export CLOUDFLARE_API_TOKEN="your-cloudflare-api-token"

# Optional: Set GitHub credentials for private images
export GITHUB_USERNAME="your-github-username"
export GITHUB_TOKEN="your-github-token"

# Run the secret setup script
cd k8s/
./setup-secrets.sh
```

### Step 2: Deploy with ArgoCD

Create an ArgoCD Application:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ski-website
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/schlagenkraft/web
    targetRevision: main
    path: k8s/base
  destination:
    server: https://kubernetes.default.svc
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
```

Or deploy manually:

```bash
kubectl apply -k k8s/base/
```

## What Gets Deployed

### From Git (via ArgoCD):
- **Namespaces**: `ski-website`, `external-dns`
- **ClusterIssuer**: `ski-dev-issuer` for Let's Encrypt SSL
- **External-DNS**: Automatic DNS management for ski.dev
- **Application**: Nginx serving static website
- **Service**: LoadBalancer with MetalLB
- **Ingress**: HTTPS termination with cert-manager

### Created Manually (NOT in Git):
- Cloudflare API token secrets
- GitHub Container Registry pull secrets
- Any other sensitive credentials

## Environment-Specific Deployments

### Production (ski.dev)
```bash
kubectl apply -k k8s/prod/
```
- Domain: ski.dev, www.ski.dev
- Replicas: 3
- Resources: Higher limits

### Staging
```bash
kubectl apply -k k8s/staging/
```
- Domain: staging.ski.dev
- Replicas: 2
- Resources: Medium limits

### Development
```bash
kubectl apply -k k8s/dev/
```
- Domain: dev.ski.dev
- Replicas: 1
- Resources: Lower limits

## Monitoring

### Check deployment status:
```bash
kubectl get all -n ski-website
kubectl get ingress -n ski-website
kubectl get certificate -n ski-website
```

### Check SSL certificate:
```bash
kubectl describe certificate -n ski-website
kubectl get certificaterequest -n ski-website
```

### Check DNS updates:
```bash
kubectl logs -n external-dns -l app=external-dns-ski-dev
```

### Access the site:
- Via LoadBalancer IP: `http://<EXTERNAL-IP>`
- Via domain (after DNS propagation): `https://ski.dev`

## Troubleshooting

### Certificate not issuing:
1. Check ClusterIssuer: `kubectl describe clusterissuer ski-dev-issuer`
2. Check secrets exist: `kubectl get secrets -n cert-manager`
3. Check challenges: `kubectl get challenges -A`

### DNS not updating:
1. Check external-dns logs: `kubectl logs -n external-dns -l app=external-dns-ski-dev`
2. Verify Cloudflare token permissions
3. Check secret exists: `kubectl get secrets -n external-dns`

### Image pull errors:
1. Verify ghcr-io-cred secret: `kubectl get secrets -n ski-website`
2. Re-run setup-secrets.sh with GitHub credentials

## Security Notes

- **NEVER** commit secrets to Git
- Use `.gitignore` to prevent accidental commits
- Rotate API tokens regularly
- Use separate tokens for different environments
- Consider using Sealed Secrets or External Secrets Operator for production

## CI/CD Integration

For automated deployments:

1. **GitHub Actions**: Push to main branch
2. **ArgoCD**: Automatically syncs from Git
3. **Image updates**: Use Kustomize image transformations
4. **Rollbacks**: Via ArgoCD UI or Git revert

Example image update:
```bash
cd k8s/prod/
kustomize edit set image ghcr.io/schlagenkraft/web/ski-website:v1.2.3
git commit -am "Update to v1.2.3"
git push
# ArgoCD automatically deploys the change
```