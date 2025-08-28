FROM nginx:alpine

# Install certbot and certbot nginx plugin
RUN apk add --no-cache certbot certbot-nginx bash

# Create directories for certbot
RUN mkdir -p /var/www/certbot
RUN mkdir -p /etc/letsencrypt

# Copy nginx configuration files
COPY nginx/nginx.conf /etc/nginx/nginx.conf
COPY nginx/conf.d/ /etc/nginx/conf.d/
COPY nginx/ssl/ /etc/nginx/ssl/

# Copy static website content
COPY html/ /usr/share/nginx/html/

# Copy certbot renewal script
COPY scripts/certbot-renew.sh /usr/local/bin/certbot-renew.sh
RUN chmod +x /usr/local/bin/certbot-renew.sh

# Expose ports
EXPOSE 80 443

# Start nginx in foreground
CMD ["nginx", "-g", "daemon off;"]