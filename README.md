# Ski Website - Dockerized Nginx with SSL

A production-ready static website setup using Docker, Nginx, Let's Encrypt SSL certificates, and Cloudflare DNS support.

## Features

- ✅ Nginx Alpine-based Docker container
- ✅ SSL/TLS support with Let's Encrypt
- ✅ Separate SSL configuration file for custom settings
- ✅ Cloudflare DNS integration ready
- ✅ Automatic certificate renewal
- ✅ Multi-platform support (Apple Silicon & Linux x86_64)
- ✅ Security headers configured
- ✅ Gzip compression enabled
- ✅ Static asset caching

## Project Structure

```
.
├── Dockerfile                 # Multi-stage Docker build
├── docker-compose.yml         # Docker Compose configuration
├── .env.example              # Environment variables template
├── html/                     # Static website content
│   ├── index.html
│   ├── 404.html
│   └── 50x.html
├── nginx/
│   ├── nginx.conf            # Main nginx configuration
│   ├── conf.d/
│   │   └── default.conf      # Site configuration
│   └── ssl/
│       └── ssl-params.conf   # Custom SSL parameters (customizable)
├── scripts/
│   └── certbot-renew.sh     # Certificate renewal script
└── certbot/                  # Certbot data (auto-created)
    ├── www/                  # ACME challenge directory
    └── conf/                 # Let's Encrypt certificates
```

## Prerequisites

- Docker installed
- Docker Compose installed
- Domain name pointed to your server
- Ports 80 and 443 available

## Setup Instructions

### 1. Clone and Configure

```bash
# Copy environment template
cp .env.example .env

# Edit .env with your domain and email
vim .env
```

### 2. Custom SSL Configuration

The SSL configuration is separated in `nginx/ssl/ssl-params.conf`. You can modify this file to add your custom SSL settings:

```bash
# Edit SSL parameters
vim nginx/ssl/ssl-params.conf
```

Common customizations:
- Add custom cipher suites
- Enable/disable HSTS
- Configure OCSP stapling
- Add DH parameters
- Modify session cache settings

### 3. Build and Run

#### For Development (Apple Silicon)

```bash
# Build the image
docker compose build

# Run without SSL (for local testing)
docker compose up nginx
```

#### For Production (with SSL)

```bash
# Set production environment
export STAGING=0  # Use Let's Encrypt production servers

# Initial setup - get certificates
docker compose up -d

# Run certificate creation
docker compose exec nginx /usr/local/bin/certbot-renew.sh

# Restart to apply certificates
docker compose restart nginx
```

### 4. Multi-Platform Build

For deployment to Linux x86_64 from Apple Silicon:

```bash
# Build for multiple platforms
docker buildx create --name multiplatform --use
docker buildx build --platform linux/amd64,linux/arm64 -t ski-website:latest --push .
```

## Managing SSL Certificates

### Initial Certificate Creation

```bash
# Test with staging certificates first
STAGING=1 docker compose exec nginx /usr/local/bin/certbot-renew.sh

# Once working, get production certificates
STAGING=0 docker compose exec nginx /usr/local/bin/certbot-renew.sh
```

### Manual Renewal

```bash
docker compose exec nginx certbot renew
docker compose exec nginx nginx -s reload
```

### Automatic Renewal

The certbot container automatically checks for renewal every 12 hours.

## Adding Custom Content

1. Place your static files in the `html/` directory
2. The container will automatically serve them
3. No rebuild required - volume mounted

```bash
# Add your website files
cp -r /path/to/your/site/* html/
```

## Cloudflare Integration

For Cloudflare DNS validation (optional):

1. Get your Cloudflare API token
2. Add to `.env` file:
```bash
CF_API_TOKEN=your_token_here
CF_ZONE_ID=your_zone_id_here
```

3. Update certbot command to use DNS validation

## Security Considerations

- SSL certificates are stored in `certbot/conf/`
- Keep your `.env` file secure (add to .gitignore)
- Regularly update the Docker images
- Monitor certificate expiration
- Test with staging certificates before production

## Troubleshooting

### Certificate Issues

```bash
# Check certificate status
docker compose exec nginx certbot certificates

# View nginx error logs
docker compose logs nginx

# Test nginx configuration
docker compose exec nginx nginx -t
```

### Port Conflicts

```bash
# Check if ports are in use
lsof -i :80
lsof -i :443
```

### DNS Issues

```bash
# Verify DNS is pointing to your server
nslookup yourdomain.com
dig yourdomain.com
```

## Commands Reference

```bash
# Start services
docker compose up -d

# Stop services
docker compose down

# View logs
docker compose logs -f

# Rebuild after changes
docker compose build
docker compose up -d --force-recreate

# Access nginx container
docker compose exec nginx sh

# Reload nginx config
docker compose exec nginx nginx -s reload
```

## Production Checklist

- [ ] Domain DNS configured
- [ ] Environment variables set
- [ ] Custom SSL parameters configured
- [ ] Test with staging certificates
- [ ] Switch to production certificates
- [ ] Enable HSTS (if desired)
- [ ] Set up monitoring
- [ ] Configure backups for certificates
- [ ] Set up log rotation

## License

MIT