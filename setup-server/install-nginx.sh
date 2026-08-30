#!/usr/bin/env bash
# install-nginx.sh — Install and enable Nginx on Ubuntu.
# Optional TLS via certbot:  DOMAIN=example.duckdns.org bash install-nginx.sh
# Safe to run non-interactively:  curl -fsSL <raw-url> | bash

set -euo pipefail

SITE_NAME="${SITE_NAME:-server_default}"
DOMAIN="${DOMAIN:-}"          # leave empty to skip the certbot step
CERTBOT_EMAIL="${CERTBOT_EMAIL:-}"

# Update package index
sudo apt-get update

# Install Nginx
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y nginx

# Enable Nginx to start on boot and start it now
sudo systemctl enable nginx
sudo systemctl start nginx

# Check status (`|| true` so `set -e` doesn't abort on a non-zero exit code)
sudo systemctl status nginx --no-pager || true

# ---- Virtual host -----------------------------------------------------------
# Create the vhost BEFORE symlinking it; the original script linked a file that
# did not exist yet and then opened $EDITOR, which cannot work under `curl | bash`.
AVAILABLE="/etc/nginx/sites-available/$SITE_NAME"
ENABLED="/etc/nginx/sites-enabled/$SITE_NAME"

if [ ! -f "$AVAILABLE" ]; then
  echo "→ Creating placeholder vhost $AVAILABLE"
  sudo tee "$AVAILABLE" > /dev/null <<NGINX_EOF
server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN:-_};

    root /var/www/html;
    index index.html;

    location / {
        try_files \$uri \$uri/ =404;
    }
}
NGINX_EOF
fi

# ln -s fails if the link already exists; -f -n makes the script re-runnable.
sudo ln -sfn "$AVAILABLE" "$ENABLED"

sudo nginx -t                  # check syntax before reloading
sudo systemctl reload nginx

# ---- TLS (optional) ---------------------------------------------------------
if [ -n "$DOMAIN" ]; then
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y certbot python3-certbot-nginx
  if [ -n "$CERTBOT_EMAIL" ]; then
    sudo certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos -m "$CERTBOT_EMAIL"
  else
    # Interactive: certbot will prompt for an email address.
    sudo certbot --nginx -d "$DOMAIN"
  fi
  sudo nginx -t
  sudo systemctl reload nginx
fi

echo "✅ Nginx ready. Edit $AVAILABLE, then: sudo nginx -t && sudo systemctl reload nginx"
