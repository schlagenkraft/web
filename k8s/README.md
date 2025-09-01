# Kubernetes Deployment with Kustomize

This directory contains Kubernetes manifests organized for Kustomize deployment.

## Directory Structure

```
k8s/
├── base/                  # Base configuration
│   ├── namespace.yaml
│   ├── configmap.yaml
│   ├── service.yaml
│   ├── deployment.yaml
│   ├── ingress.yaml
│   └── kustomization.yaml
├── dev/                   # Development overlay
│   ├── deployment-patch.yaml
│   └── kustomization.yaml
└── prod/                  # Production overlay
    ├── deployment-patch.yaml
    └── kustomization.yaml
```

## Prerequisites

- kubectl installed and configured
- Access to Kubernetes cluster
- Container image pushed to `ghcr.io/schlagenkraft/ski-website`

## Deployment

### Deploy to Development
```bash
kubectl apply -k k8s/dev/
```

### Deploy to Production
```bash
kubectl apply -k k8s/prod/
```

### Preview Generated Manifests
```bash
# Preview development manifests
kubectl kustomize k8s/dev/

# Preview production manifests
kubectl kustomize k8s/prod/
```

## Image Management

The deployment uses the image `ghcr.io/schlagenkraft/ski-website` with different tags:
- Development: `dev` tag
- Production: `latest` tag

To update the image tag without editing files:
```bash
# Update production image
cd k8s/prod/
kustomize edit set image ghcr.io/schlagenkraft/ski-website:v1.2.3

# Update development image
cd k8s/dev/
kustomize edit set image ghcr.io/schlagenkraft/ski-website:dev-abc123
```

## Environment Differences

### Development (dev/)
- Namespace: `ski-website-dev`
- Replicas: 1
- Resource limits: Lower (200m CPU, 128Mi memory)
- Name prefix: `dev-`

### Production (prod/)
- Namespace: `ski-website`
- Replicas: 3
- Resource limits: Higher (1000m CPU, 512Mi memory)
- Name prefix: `prod-`

## Required Secrets

Before deploying, ensure these secrets exist in the target namespace:

1. **ghcr-secret**: Docker registry credentials for pulling images from GitHub Container Registry
   ```bash
   kubectl create secret docker-registry ghcr-secret \
     --docker-server=ghcr.io \
     --docker-username=<github-username> \
     --docker-password=<github-token> \
     -n ski-website
   ```

2. **ssl-certificates** (optional): SSL certificates for HTTPS
   - This secret should contain the SSL certificate files
   - If not present, the deployment will still work but without custom SSL

## Ingress Configuration

The base ingress is configured with placeholder domains (`example.com`). 
Update the hosts in a production overlay patch:

```yaml
# k8s/prod/ingress-patch.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ski-website
spec:
  rules:
  - host: your-actual-domain.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: prod-ski-website
            port:
              number: 80
```

Then add to `k8s/prod/kustomization.yaml`:
```yaml
patches:
  - path: ingress-patch.yaml
    target:
      kind: Ingress
      name: ski-website
```

## Monitoring

Check deployment status:
```bash
kubectl get deployments -n ski-website
kubectl get pods -n ski-website
kubectl get services -n ski-website
kubectl get ingress -n ski-website
```

View logs:
```bash
kubectl logs -n ski-website -l app=ski-website
```

## Cleanup

Remove deployment:
```bash
# Remove development
kubectl delete -k k8s/dev/

# Remove production
kubectl delete -k k8s/prod/
```