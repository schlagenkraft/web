#!/bin/bash

# Script to manually create secrets for cert-manager and external-dns
# These secrets are NOT stored in Git for security reasons
# Run this script BEFORE deploying with ArgoCD/GitOps

set -e

echo "==================================="
echo "Kubernetes Secrets Setup for ski.dev"
echo "==================================="
echo ""

# Check if required environment variable is set
if [ -z "$CLOUDFLARE_API_TOKEN" ]; then
    echo "ERROR: CLOUDFLARE_API_TOKEN environment variable is not set"
    echo ""
    echo "Please set your Cloudflare API token:"
    echo "  export CLOUDFLARE_API_TOKEN='your-cloudflare-api-token'"
    echo ""
    echo "The token needs the following permissions:"
    echo "  - Zone:Read"
    echo "  - Zone:DNS:Edit"
    echo "  - Zone:DNS:Read"
    echo ""
    exit 1
fi

echo "Prerequisites check..."
echo "✓ CLOUDFLARE_API_TOKEN is set"
echo ""

# Create namespaces if they don't exist
echo "Creating namespaces if needed..."
kubectl create namespace cert-manager --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace external-dns --dry-run=client -o yaml | kubectl apply -f -
echo "✓ Namespaces ready"
echo ""

# Create cert-manager secret for Cloudflare
echo "Creating cert-manager Cloudflare API token secret..."
kubectl create secret generic cloudflare-api-token-secret-ski-dev \
  --from-literal=api-token="$CLOUDFLARE_API_TOKEN" \
  --namespace=cert-manager \
  --dry-run=client -o yaml | kubectl apply -f -
echo "✓ cert-manager secret created"
echo ""

# Create external-dns secret for Cloudflare
echo "Creating external-dns Cloudflare API token secret..."
kubectl create secret generic cloudflare-api-secret-ski-dev \
  --from-literal=CF_API_TOKEN="$CLOUDFLARE_API_TOKEN" \
  --namespace=external-dns \
  --dry-run=client -o yaml | kubectl apply -f -
echo "✓ external-dns secret created"
echo ""

# Create ghcr.io pull secret if provided
if [ ! -z "$GITHUB_TOKEN" ] && [ ! -z "$GITHUB_USERNAME" ]; then
    echo "Creating GitHub Container Registry pull secret..."
    kubectl create secret docker-registry ghcr-io-cred \
      --docker-server=ghcr.io \
      --docker-username="$GITHUB_USERNAME" \
      --docker-password="$GITHUB_TOKEN" \
      --docker-email="${GITHUB_EMAIL:-noreply@github.com}" \
      --namespace=ski-website \
      --dry-run=client -o yaml | kubectl apply -f -
    echo "✓ ghcr.io pull secret created"
else
    echo "ℹ️  Skipping ghcr.io pull secret (set GITHUB_TOKEN and GITHUB_USERNAME to create)"
fi
echo ""

echo "==================================="
echo "Secret setup complete!"
echo "==================================="
echo ""
echo "Next steps:"
echo "1. Deploy the application with ArgoCD or kubectl:"
echo "   kubectl apply -k k8s/base/"
echo ""
echo "2. Monitor certificate issuance:"
echo "   kubectl get certificates -n ski-website"
echo "   kubectl describe certificate -n ski-website"
echo ""
echo "3. Check external-dns logs:"
echo "   kubectl logs -n external-dns -l app=external-dns-ski-dev"
echo ""