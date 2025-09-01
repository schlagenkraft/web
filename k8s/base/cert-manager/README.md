# Ski.dev Cert-Manager Configuration

## Files Created:
- `03-k8s-secret-cloudflare-ski-dev.yaml` - Cloudflare API token secret for ski.dev
- `04-issuer-manifest-cloudflare-ski-dev.yaml` - ClusterIssuer for ski.dev domain
- `05-cert-request-ski-dev.yaml` - Certificate request for ski.dev and *.ski.dev

## Creating Cloudflare API Token

### Via Cloudflare Dashboard:
1. Log into your Cloudflare account at https://dash.cloudflare.com
2. Go to "My Profile" → "API Tokens"
3. Click "Create Token"
4. Use the "Edit zone DNS" template or create a custom token with:
   - Permissions: 
     - Zone → DNS → Edit
     - Zone → Zone → Read
   - Zone Resources: Include → Specific zone → ski.dev
5. Copy the generated token

### Via Cloudflare API:
```bash
# Create API token using Cloudflare API (requires existing API key)
curl -X POST "https://api.cloudflare.com/client/v4/user/tokens" \
  -H "X-Auth-Email: your-email@example.com" \
  -H "X-Auth-Key: your-global-api-key" \
  -H "Content-Type: application/json" \
  --data '{
    "name": "cert-manager-ski-dev",
    "policies": [
      {
        "effect": "allow",
        "resources": {
          "com.cloudflare.api.account.zone.*": "*"
        },
        "permission_groups": [
          {
            "id": "c8fed203ed3043cba015a93ad1616f1f",
            "name": "Zone Read"
          },
          {
            "id": "4755a26eedb94da69e1066d98aa820be",
            "name": "DNS Write"
          }
        ]
      }
    ]
  }'
```

## Applying the Configuration:

1. First, encode your Cloudflare API token:
```bash
echo -n "your-cloudflare-api-token" | base64
```

2. Update the secret with your encoded token:
```bash
# Edit the file and replace 'base64changerme-ski-dev' with your encoded token
kubectl apply -f ski-dev/03-k8s-secret-cloudflare-ski-dev.yaml
```

3. Apply the issuer:
```bash
kubectl apply -f ski-dev/04-issuer-manifest-cloudflare-ski-dev.yaml
```

4. Apply the certificate requests:
```bash
kubectl apply -f ski-dev/05-cert-request-ski-dev.yaml
```

## Verify the setup:
```bash
# Check if the issuer is ready
kubectl get clusterissuer ski-dev-issuer

# Check certificate status
kubectl get certificates -A | grep ski-dev

# Check if secrets were created
kubectl get secrets -A | grep ski-dev-tls
```

## Managing Multiple Cloudflare Accounts:

Each Cloudflare account/domain gets its own:
- API token secret (with unique name suffix)
- ClusterIssuer (with unique name)
- Certificate resources (referencing the appropriate issuer)

All can coexist in the same namespace since they use different resource names.
