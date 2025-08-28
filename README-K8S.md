# Kubernetes Deployment with GitHub Container Registry (GHCR)

This guide covers deploying the Ski Website to Kubernetes using GitHub Container Registry for image storage.

## Prerequisites

- Kubernetes cluster (1.19+)
- kubectl configured
- GitHub repository
- cert-manager installed (for SSL certificates)

## GitHub Container Registry Setup

### 1. Enable GitHub Packages

GitHub Packages is enabled by default for all repositories.

### 2. Create Personal Access Token (for local development)

1. Go to GitHub Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Click "Generate new token"
3. Give it a name (e.g., "ghcr-ski-website")
4. Select scopes:
   - `read:packages`
   - `write:packages`
   - `delete:packages` (optional)
5. Generate and save the token

### 3. Login to GHCR Locally

```bash
# Using personal access token
echo $YOUR_TOKEN | docker login ghcr.io -u YOUR_GITHUB_USERNAME --password-stdin

# Or using GitHub CLI
gh auth token | docker login ghcr.io -u YOUR_GITHUB_USERNAME --password-stdin
```

### 4. Build and Push Manually (for testing)

```bash
# Build for multiple platforms
docker buildx create --name multiplatform --use
docker buildx build --platform linux/amd64,linux/arm64 \
  -t ghcr.io/YOUR_GITHUB_ORG/ski-website:latest \
  --push .
```

## GitHub Actions Setup

### 1. Repository Secrets

The workflow uses the built-in `GITHUB_TOKEN` which has automatic permissions for packages in the same repository.

For Kubernetes deployment, add these secrets:

1. **KUBE_CONFIG**: Base64 encoded kubeconfig
   ```bash
   # Get your kubeconfig and encode it
   cat ~/.kube/config | base64 | pbcopy
   ```
   - Go to Repository Settings → Secrets and variables → Actions
   - Add new repository secret named `KUBE_CONFIG`
   - Paste the base64 encoded content

### 2. Workflow Permissions

Ensure your repository has the correct permissions:

1. Go to Settings → Actions → General
2. Under "Workflow permissions", select:
   - "Read and write permissions"
   - "Allow GitHub Actions to create and approve pull requests" (optional)

### 3. Package Visibility

After first push, configure package visibility:

1. Go to your GitHub profile → Packages
2. Find `ski-website` package
3. Package settings → Manage Actions access
4. Add your repository if not already linked

## Kubernetes Deployment

### 1. Create Namespace

```bash
kubectl apply -f k8s/namespace.yaml
```

### 2. Create Image Pull Secret

```bash
# Create secret for pulling images from GHCR
kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=YOUR_GITHUB_USERNAME \
  --docker-password=YOUR_GITHUB_TOKEN \
  --docker-email=YOUR_EMAIL \
  -n ski-website
```

### 3. Update Deployment Image

Edit `k8s/deployment.yaml` and replace `YOUR_GITHUB_ORG` with your GitHub organization or username:

```yaml
image: ghcr.io/YOUR_GITHUB_ORG/ski-website:latest
```

### 4. Apply Configurations

```bash
# Apply all configurations
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/ingress.yaml
```

### 5. Verify Deployment

```bash
# Check deployment status
kubectl get pods -n ski-website
kubectl get svc -n ski-website
kubectl get ingress -n ski-website

# View logs
kubectl logs -f deployment/ski-website -n ski-website

# Describe deployment
kubectl describe deployment ski-website -n ski-website
```

## SSL Certificate Management

### Option 1: cert-manager (Recommended)

1. Install cert-manager:
```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
```

2. Create ClusterIssuer:
```bash
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: YOUR_EMAIL
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
EOF
```

### Option 2: Manual Certificate

1. Create certificate locally or from existing source
2. Create Kubernetes secret:
```bash
kubectl create secret tls ski-website-tls \
  --cert=path/to/cert.pem \
  --key=path/to/key.pem \
  -n ski-website
```

## Custom SSL Configuration

The SSL parameters are stored in a ConfigMap and can be updated:

```bash
# Edit the SSL configuration
kubectl edit configmap nginx-ssl-config -n ski-website

# Restart pods to apply changes
kubectl rollout restart deployment/ski-website -n ski-website
```

## Continuous Deployment

The GitHub Actions workflow automatically:

1. Builds multi-platform Docker images on push to main/master
2. Tags images with:
   - Branch name
   - Git SHA
   - Semantic version (if using tags)
   - `latest` for main branch
3. Pushes to GHCR
4. Updates Kubernetes deployment (if KUBE_CONFIG secret is set)

### Manual Deployment Trigger

```bash
# Tag a release to trigger deployment
git tag -a v1.0.0 -m "Release version 1.0.0"
git push origin v1.0.0
```

## Troubleshooting

### Image Pull Errors

```bash
# Check if secret exists
kubectl get secret ghcr-secret -n ski-website

# Verify secret works
kubectl create pod test-pull --image=ghcr.io/YOUR_ORG/ski-website:latest \
  --dry-run=client -o yaml | kubectl apply -f -
```

### GHCR Access Issues

```bash
# Verify you can pull the image locally
docker pull ghcr.io/YOUR_ORG/ski-website:latest

# Check package visibility on GitHub
# Profile → Packages → ski-website → Settings
```

### Pod Not Starting

```bash
# Check pod events
kubectl describe pod POD_NAME -n ski-website

# Check logs
kubectl logs POD_NAME -n ski-website

# Check resource limits
kubectl top pods -n ski-website
```

### SSL Certificate Issues

```bash
# Check cert-manager logs
kubectl logs -n cert-manager deployment/cert-manager

# Check certificate status
kubectl get certificate -n ski-website
kubectl describe certificate ski-website-tls -n ski-website
```

## Monitoring

### Basic Health Checks

```bash
# Check endpoint health
curl -I https://your-domain.com

# Check from inside cluster
kubectl run test-curl --image=curlimages/curl -it --rm -- sh
curl -I http://ski-website.ski-website.svc.cluster.local
```

### View Metrics

```bash
# If metrics-server is installed
kubectl top pods -n ski-website
kubectl top nodes
```

## Scaling

```bash
# Manual scaling
kubectl scale deployment ski-website --replicas=5 -n ski-website

# Autoscaling
kubectl autoscale deployment ski-website \
  --cpu-percent=80 \
  --min=3 \
  --max=10 \
  -n ski-website
```

## Rollback

```bash
# View rollout history
kubectl rollout history deployment/ski-website -n ski-website

# Rollback to previous version
kubectl rollout undo deployment/ski-website -n ski-website

# Rollback to specific revision
kubectl rollout undo deployment/ski-website --to-revision=2 -n ski-website
```

## Clean Up

```bash
# Delete all resources in namespace
kubectl delete namespace ski-website

# Or delete individually
kubectl delete -f k8s/
```

## Security Best Practices

1. **Use specific image tags** instead of `latest` in production
2. **Implement NetworkPolicies** to restrict pod communication
3. **Use PodSecurityPolicies** or Pod Security Standards
4. **Regularly update** base images and dependencies
5. **Scan images** for vulnerabilities using GitHub's dependency scanning
6. **Rotate secrets** periodically
7. **Use RBAC** to limit access to namespace resources

## Integration with Cloudflare

If using Cloudflare:

1. Set SSL mode to "Full (strict)" in Cloudflare
2. Update DNS records to point to Kubernetes LoadBalancer/Ingress IP
3. Consider using Cloudflare Tunnel for additional security