#!/bin/bash

DOMAIN1="api.knmholdings.vn"
DOCKER_IP1="YOUR_DOCKER_IP_FOR_API" 

DOMAIN2="devapi.knmholdings.vn"
DOCKER_IP2="YOUR_DOCKER_IP_FOR_DEVAPI"

LETSENCRYPT_EMAIL="hieuhpcf@gmail.com" 

PREFIX="core-asterisk-service"
SWAGGER="apis"

if [ "$(id -u)" -ne 0 ]; then
  echo "Please run this script with root privileges or sudo."
  exit 1
fi


if [ "$DOCKER_IP1" = "YOUR_DOCKER_IP_FOR_API" ] || \
   [ "$DOCKER_IP2" = "YOUR_DOCKER_IP_FOR_DEVAPI" ] || \
   [ "$LETSENCRYPT_EMAIL" = "hieuhpcf@gmail.com" ]; then
  echo "ERROR: Please edit the script and update the variables:"
  echo "DOCKER_IP1, DOCKER_IP2, and LETSENCRYPT_EMAIL."
  exit 1
fi

create_nginx_config() {
  local domain="$1"
  local docker_ip="$2"
  local config_file="/etc/nginx/sites-available/${domain}"

  echo ">>> Creating initial Nginx configuration for ${domain}..."
  sudo tee "$config_file" > /dev/null <<EOF
server {
    listen 80;
    server_name ${domain};


    location /${PREFIX} {
        proxy_pass http://${docker_ip}:3000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    location /${SWAGGER} {
	proxy_pass http://${docker_ip}:3000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
EOF

  sudo ln -sf "$config_file" "/etc/nginx/sites-enabled/"
  echo "Created ${config_file} and linked to sites-enabled."
}

echo "=== Starting Nginx and Let's Encrypt setup for ${DOMAIN1} and ${DOMAIN2} ==="
echo ">>> Installing Nginx and Certbot (with Nginx plugin)..."

sudo apt update
sudo apt install -y nginx certbot python3-certbot-nginx curl

echo ">>> Configuring firewall (UFW)..."

sudo ufw allow 'Nginx Full' 
# If UFW is not enabled, you might want to enable it.
# Be careful if you are SSHing, ensure SSH port is allowed (usually 'OpenSSH').
# sudo ufw enable
sudo ufw status

create_nginx_config "$DOMAIN1" "$DOCKER_IP1"
create_nginx_config "$DOMAIN2" "$DOCKER_IP2"

echo ">>> Checking Nginx configuration..."

sudo nginx -t
if [ $? -ne 0 ]; then
  echo "ERROR: Nginx configuration is invalid. Please check!"
  exit 1
fi

echo ">>> Reloading Nginx..."

sudo systemctl reload nginx

echo ">>> Obtaining SSL certificate for ${DOMAIN1}..."
sudo certbot --nginx -d "${DOMAIN1}" --non-interactive --agree-tos -m "${LETSENCRYPT_EMAIL}" --redirect

echo ">>> Obtaining SSL certificate for ${DOMAIN2}..."
sudo certbot --nginx -d "${DOMAIN2}" --non-interactive --agree-tos -m "${LETSENCRYPT_EMAIL}" --redirect

echo ">>> Re-checking Nginx configuration after Certbot run..."

sudo nginx -t
if [ $? -ne 0 ]; then
  echo "ERROR: Nginx configuration is invalid after Certbot run. Please check files in /etc/nginx/sites-available/"
  exit 1
fi

echo ">>> Reloading Nginx with SSL configuration..."

sudo systemctl reload nginx

echo ">>> Checking Certbot auto-renewal mechanism (dry run)..."
sudo certbot renew --dry-run
echo "Check systemd timers: sudo systemctl list-timers | grep certbot"

echo ""
echo "=== SETUP COMPLETE ==="
echo "Your subdomains should now be accessible via HTTPS:"
echo "https://${DOMAIN1}"
echo "https://${DOMAIN2}"
echo ""
echo "IMPORTANT:"
echo "- Ensure Docker containers at ${DOCKER_IP1}:3000 and ${DOCKER_IP2}:3000 are running."
echo "- DNS records for ${DOMAIN1} and ${DOMAIN2} MUST point to this server's public IP."
echo "- If errors occur, check Nginx logs (usually at /var/log/nginx/error.log) and configuration files in /etc/nginx/sites-available/."
echo "---------------------------------------------------------------------"
