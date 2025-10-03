#!/bin/bash
set -e

# Update package index
sudo apt update -y

# Install Nginx
sudo apt install -y nginx

# Enable Nginx to start on boot
sudo systemctl enable nginx

# Start Nginx service
sudo systemctl start nginx

# Check Nginx status
sudo systemctl status nginx --no-pager



sudo ln -s /etc/nginx/sites-available/server_default /etc/nginx/sites-enabled/server_default
vim /etc/nginx/sites-available/server_default
systemctl start nginx
systemctl reload nginx

sudo certbot --nginx -d novapo-develop.duckdns.org;

sudo nginx -t # check syntax
sudo systemctl reload nginx    