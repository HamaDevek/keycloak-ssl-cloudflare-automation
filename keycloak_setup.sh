#!/bin/bash
# Keycloak 26.1.1 Installation with Let's Encrypt on Ubuntu 22.04
# This script should be run as a user with sudo privileges

# Set error handling
set -e
echo "Starting Keycloak installation..."

# Update system packages
sudo apt update
sudo apt upgrade -y

# Install required dependencies
sudo apt install -y openjdk-17-jdk curl unzip nginx certbot python3-certbot-nginx python3-certbot-dns-cloudflare ufw

# Create a dedicated user for Keycloak
sudo useradd -r -m -U -d /opt/keycloak -s /bin/bash keycloak 2>/dev/null || echo "User keycloak already exists"

# Download Keycloak 26.1.1
echo "Downloading Keycloak 26.1.1..."
cd /tmp
curl -LO https://github.com/keycloak/keycloak/releases/download/26.1.1/keycloak-26.1.1.zip
unzip -q keycloak-26.1.1.zip

# Check if extraction was successful
if [ ! -d "/tmp/keycloak-26.1.1" ]; then
  echo "Error: Keycloak extraction failed!"
  exit 1
fi

# Verify the bin directory and kc.sh script exist
if [ ! -f "/tmp/keycloak-26.1.1/bin/kc.sh" ]; then
  echo "Error: kc.sh script not found in extracted archive!"
  echo "Listing bin directory contents:"
  ls -la /tmp/keycloak-26.1.1/bin/
  exit 1
fi

# Make scripts executable before moving
chmod +x /tmp/keycloak-26.1.1/bin/*.sh

# Remove old installation if it exists
if [ -d "/opt/keycloak" ]; then
  echo "Removing old Keycloak installation..."
  sudo rm -rf /opt/keycloak
fi

# Move new installation
sudo mv keycloak-26.1.1 /opt/keycloak
sudo chown -R keycloak:keycloak /opt/keycloak
echo "Keycloak downloaded and extracted to /opt/keycloak"

# Verify kc.sh exists and is executable
if [ ! -x "/opt/keycloak/bin/kc.sh" ]; then
  echo "Setting executable permissions on Keycloak scripts..."
  sudo chmod +x /opt/keycloak/bin/*.sh
fi

# Create systemd service file for Keycloak
cat <<EOF | sudo tee /etc/systemd/system/keycloak.service
[Unit]
Description=Keycloak Application Server
After=network.target postgresql.service

[Service]
Type=exec
User=keycloak
Group=keycloak
ExecStart=/opt/keycloak/bin/kc.sh start --http-enabled=true --http-port=8080 --hostname=YOUR_DOMAIN
WorkingDirectory=/opt/keycloak
TimeoutStartSec=600
TimeoutStopSec=600
Restart=on-failure
RestartSec=30
Environment="JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64"

[Install]
WantedBy=multi-user.target
EOF

# Create Keycloak configuration file
sudo -u keycloak mkdir -p /opt/keycloak/conf
cat <<EOF | sudo -u keycloak tee /opt/keycloak/conf/keycloak.conf
# Basic settings
hostname=YOUR_DOMAIN
http-enabled=true
http-port=8080
https-port=8443
# Set to 'edge' for Cloudflare proxy
proxy=edge
# Recommended if using Cloudflare
proxy-headers=xforwarded

# Database settings
db=postgres
db-url=jdbc:postgresql://localhost:5432/keycloak
db-username=keycloak
db-password=your_secure_password

# Optimizations
http-relative-path=/auth
health-enabled=true
EOF

# Install and configure PostgreSQL
echo "Setting up PostgreSQL..."
sudo apt install -y postgresql postgresql-contrib
sudo systemctl enable postgresql
sudo systemctl start postgresql

# Create database and user for Keycloak
echo "Creating Keycloak database..."
sudo -u postgres psql <<EOF
CREATE DATABASE keycloak;
CREATE USER keycloak WITH ENCRYPTED PASSWORD 'your_secure_password';
GRANT ALL PRIVILEGES ON DATABASE keycloak TO keycloak;
ALTER DATABASE keycloak OWNER TO keycloak;
EOF

# Configure Nginx with SSL
cat <<EOF | sudo tee /etc/nginx/sites-available/keycloak
server {
    listen 80;
    server_name YOUR_DOMAIN;
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl;
    server_name YOUR_DOMAIN;

    ssl_certificate /etc/letsencrypt/live/YOUR_DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/YOUR_DOMAIN/privkey.pem;
    
    location / {
        proxy_pass http://localhost:8080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # Standard timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}
EOF

# Enable the Nginx site configuration
sudo ln -s /etc/nginx/sites-available/keycloak /etc/nginx/sites-enabled/ 2>/dev/null || true
sudo nginx -t
sudo systemctl restart nginx

# Configure firewall to allow HTTP and HTTPS
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw status

# Set up Let's Encrypt with Cloudflare DNS verification
# Create a Cloudflare credentials file
sudo mkdir -p /etc/letsencrypt/cloudflare
cat <<EOF | sudo tee /etc/letsencrypt/cloudflare/credentials.ini
# Cloudflare API credentials used by Certbot
dns_cloudflare_api_token = CLOUDFLARE_API_TOKEN
EOF
sudo chmod 600 /etc/letsencrypt/cloudflare/credentials.ini

# Get certificate using DNS challenge
echo "Obtaining SSL certificate..."
sudo certbot certonly --dns-cloudflare --dns-cloudflare-credentials /etc/letsencrypt/cloudflare/credentials.ini \
  -d YOUR_DOMAIN --agree-tos --non-interactive --email YOUR_EMAIL

# Build and start Keycloak
cd /opt/keycloak
echo "Building Keycloak (this may take a few minutes)..."
sudo -u keycloak /opt/keycloak/bin/kc.sh build --db=postgres

# Enable and start Keycloak service
sudo systemctl daemon-reload
sudo systemctl enable keycloak
echo "Starting Keycloak service..."
sudo systemctl start keycloak

# Wait for service to start
echo "Waiting for Keycloak to start (this may take a moment)..."
sleep 10

# Check status
echo "Checking Keycloak service status..."
sudo systemctl status keycloak

# Verify Nginx configuration and restart
echo "Verifying Nginx configuration..."
sudo nginx -t && sudo systemctl restart nginx

echo "---------------------------------------------"
echo "Keycloak 26.1.1 has been installed and configured with Let's Encrypt SSL on Ubuntu 22.04"
echo "Access your Keycloak instance at https://YOUR_DOMAIN"
echo "Initial admin user creation will be prompted on first access"
echo "---------------------------------------------"
