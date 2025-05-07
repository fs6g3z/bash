#!/bin/bash
DOMAIN1="api.knmholdings.vn"
DOCKER_IP1="localhost"

DOMAIN2="devapi.knmholdings.vn"
DOCKER_IP2="localhost"

LETSENCRYPT_EMAIL="hieuhpcf@gmail.com"

PREFIX="core-asterisk-service" # Path prefix for proxy
SWAGGER="apis"                 # Swagger path

# Check for root privileges
if [ "$(id -u)" -ne 0 ]; then
  echo "Please run this script with root privileges or sudo."
  exit 1
fi

# Check if the user has edited placeholder variables
# (You can customize these placeholder values if you wish)
if [ "$DOCKER_IP1" = "YOUR_DOCKER_IP_FOR_API" ] || \
   [ "$DOCKER_IP2" = "YOUR_DOCKER_IP_FOR_DEVAPI" ] || \
   [ "$LETSENCRYPT_EMAIL" = "fdndjfdjh" ]; then # Using the original placeholder for email
  echo "ERROR: Please edit the script and update the variables:"
  echo "DOCKER_IP1, DOCKER_IP2, and LETSENCRYPT_EMAIL."
  exit 1
fi

# Function to create Nginx configuration file
create_nginx_config() {
  local domain="$1"
  local docker_ip="$2"
  # On CentOS, configuration files are typically placed in /etc/nginx/conf.d/
  local config_file="/etc/nginx/conf.d/${domain}.conf"

  echo ">>> Creating initial Nginx configuration for ${domain}..."
  sudo tee "$config_file" > /dev/null <<EOF
server {
    listen 80;
    server_name ${domain};

    # Log access and errors separately for each domain (optional)
    access_log /var/log/nginx/${domain}.access.log;
    error_log /var/log/nginx/${domain}.error.log;

    location /${PREFIX} {
        proxy_pass http://${docker_ip}:3000; # Assuming Docker container runs on port 3000
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    location /${SWAGGER} {
        proxy_pass http://${docker_ip}:3000; # Assuming Docker container runs on port 3000
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    # Add this location for Certbot to perform HTTP-01 challenge
    location /.well-known/acme-challenge/ {
        root /var/www/html; # Or another directory where Nginx has write permissions
    }
}
EOF
  echo "Created ${config_file}."
}

echo "=== Starting Nginx and Let's Encrypt setup for ${DOMAIN1} and ${DOMAIN2} on CentOS 9 ==="

echo ">>> Installing necessary packages (Nginx, Certbot, EPEL)..."
# Install EPEL repository if not already present (required for Certbot)
if ! dnf repolist | grep -q "epel"; then
    sudo dnf install -y epel-release
fi
sudo dnf install -y nginx certbot python3-certbot-nginx curl

echo ">>> Enabling and starting Nginx..."
sudo systemctl enable --now nginx
sudo systemctl status nginx --no-pager

echo ">>> Configuring firewall (firewalld)..."
# Check if firewalld is running
if systemctl is-active --quiet firewalld; then
  sudo firewall-cmd --permanent --add-service=http
  sudo firewall-cmd --permanent --add-service=https
  sudo firewall-cmd --reload
  echo "HTTP and HTTPS ports have been opened on firewalld."
  sudo firewall-cmd --list-services
else
  echo "WARNING: firewalld is not active. Please configure your firewall manually if needed."
fi

# Create root directory for Certbot if it doesn't exist
# (Necessary for HTTP-01 challenge if Nginx doesn't have a default server block pointing there)
sudo mkdir -p /var/www/html
sudo chown nginx:nginx /var/www/html # Ensure Nginx can write here for Certbot

# Create Nginx configurations for the domains
# create_nginx_config "$DOMAIN1" "$DOCKER_IP1"
create_nginx_config "$DOMAIN2" "$DOCKER_IP2"

echo ">>> Checking Nginx configuration..."
sudo nginx -t
if [ $? -ne 0 ]; then
  echo "ERROR: Nginx configuration is invalid. Please check!"
  exit 1
fi

echo ">>> Reloading Nginx..."
sudo systemctl reload nginx

# Obtain SSL certificates
# --hsts and --uir (Upgrade-Insecure-Requests) options added for enhanced security.
# --redirect: Automatically redirect HTTP to HTTPS.

# echo ">>> Obtaining SSL certificate for ${DOMAIN1}..."
# sudo certbot --nginx -d "${DOMAIN1}" --non-interactive --agree-tos -m "${LETSENCRYPT_EMAIL}" --redirect --hsts --uir
# if [ $? -ne 0 ]; then
#  echo "ERROR: Could not obtain SSL certificate for ${DOMAIN1}. Check Certbot logs."
#  exit 1
# fi

echo ">>> Obtaining SSL certificate for ${DOMAIN2}..."
sudo certbot --nginx -d "${DOMAIN2}" --non-interactive --agree-tos -m "${LETSENCRYPT_EMAIL}" --redirect --hsts --uir
if [ $? -ne 0 ]; then
  echo "ERROR: Could not obtain SSL certificate for ${DOMAIN2}. Check Certbot logs."
  exit 1
fi

echo ">>> Re-checking Nginx configuration after Certbot run..."
sudo nginx -t
if [ $? -ne 0 ]; then
  echo "ERROR: Nginx configuration is invalid after Certbot run. Please check files in /etc/nginx/conf.d/"
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
echo "https://${DOMAIN1}/${PREFIX}"
echo "https://${DOMAIN1}/${SWAGGER}"
echo "https://${DOMAIN2}/${PREFIX}"
echo "https://${DOMAIN2}/${SWAGGER}"
echo ""
echo "IMPORTANT:"
echo "- Ensure Docker containers at ${DOCKER_IP1}:3000 and ${DOCKER_IP2}:3000 are running."
echo "  (If your Docker containers use a different port, update the proxy_pass directive in the Nginx configs)."
echo "- DNS records for ${DOMAIN1} and ${DOMAIN2} MUST point to this server's public IP."
echo "- If errors occur, check Nginx logs (usually at /var/log/nginx/error.log and /var/log/nginx/<domain_name>.error.log) and configuration files in /etc/nginx/conf.d/."
echo "---------------------------------------------------------------------"
