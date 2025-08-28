#!/bin/bash

# Certbot certificate renewal script
# This script handles SSL certificate creation and renewal

DOMAIN=${DOMAIN_NAME:-example.com}
EMAIL=${EMAIL:-admin@example.com}
STAGING=${STAGING:-0}

# Function to check if certificate exists
check_certificate() {
    if [ -f "/etc/letsencrypt/live/${DOMAIN}/fullchain.pem" ]; then
        echo "Certificate exists for ${DOMAIN}"
        return 0
    else
        echo "Certificate does not exist for ${DOMAIN}"
        return 1
    fi
}

# Function to create new certificate
create_certificate() {
    echo "Creating new certificate for ${DOMAIN}..."
    
    STAGING_FLAG=""
    if [ "${STAGING}" = "1" ]; then
        STAGING_FLAG="--staging"
        echo "Using Let's Encrypt staging server"
    fi
    
    certbot certonly \
        --webroot \
        --webroot-path=/var/www/certbot \
        --email ${EMAIL} \
        --agree-tos \
        --no-eff-email \
        --force-renewal \
        ${STAGING_FLAG} \
        -d ${DOMAIN} \
        -d www.${DOMAIN}
    
    if [ $? -eq 0 ]; then
        echo "Certificate created successfully"
        nginx -s reload
        return 0
    else
        echo "Failed to create certificate"
        return 1
    fi
}

# Function to renew certificate
renew_certificate() {
    echo "Attempting to renew certificates..."
    certbot renew --quiet --webroot --webroot-path=/var/www/certbot
    
    if [ $? -eq 0 ]; then
        echo "Certificates renewed successfully"
        nginx -s reload
        return 0
    else
        echo "Certificate renewal failed or not due"
        return 1
    fi
}

# Main logic
if check_certificate; then
    renew_certificate
else
    create_certificate
fi

# Set up automatic renewal (run this script via cron)
# Add to crontab: 0 0,12 * * * /usr/local/bin/certbot-renew.sh