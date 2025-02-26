Here's a complete summary of the readme file:

# Keycloak 26.1.1 Installation Guide

This guide covers installing and configuring Keycloak 26.1.1 with Let's Encrypt SSL on Ubuntu 22.04.

## Important Security Notice
Before running the installation script, you MUST replace:
- `YOUR_DOMAIN` with YOUR domain
- `YOUR_EMAIL` with YOUR email
- `CLOUDFLARE_API_TOKEN` with YOUR Cloudflare API token
- `your_secure_password` with YOUR strong database password

## Overview
The installation script automates:
- System updates and required dependencies installation
- Keycloak 26.1.1 download and setup
- PostgreSQL database configuration
- Nginx as a reverse proxy with Let's Encrypt SSL
- Cloudflare DNS verification for SSL
- UFW firewall configuration
- Systemd service for Keycloak

## Prerequisites
- Ubuntu 22.04 LTS server
- A user with sudo privileges
- Domain pointed to your server
- Cloudflare DNS account with the domain added

## Installation Instructions
1. Download the installation script to your server
2. Modify the script to update domain name, database password, email address, and Cloudflare API token
   - To generate a Cloudflare API token:
     1. Log in to your Cloudflare account
     2. Go to My Profile > API Tokens
     3. Create a token with Zone:DNS:Edit permissions for your specific domain
3. Make the script executable: `chmod +x keycloak_install.sh`
4. Run the script: `./keycloak_install.sh`

## Post-Installation Steps

### Creating an Admin User
By default, Keycloak doesn't create an initial admin user. To create the first admin user:
```bash
sudo -u keycloak /opt/keycloak/bin/kc.sh bootstrap-admin user
```
This command creates a temporary admin user and displays the credentials in the console. Use these credentials to log in to the Keycloak Admin Console at https://your-domain/admin/ and then create permanent admin users.

### Security Considerations
1. CRITICAL: After installation, remove the Cloudflare API token from `/etc/letsencrypt/cloudflare/credentials.ini`
2. Verify you've properly replaced the default database password in `/opt/keycloak/conf/keycloak.conf`
3. Consider disabling HTTP once HTTPS is working correctly
4. Review all configuration files to ensure no default values remain

## Configuration Files
- Keycloak configuration: `/opt/keycloak/conf/keycloak.conf`
- Nginx site configuration: `/etc/nginx/sites-available/keycloak`
- Systemd service: `/etc/systemd/system/keycloak.service`
- Cloudflare credentials: `/etc/letsencrypt/cloudflare/credentials.ini`

## Troubleshooting

### Service Issues
Check service status:
```bash
sudo systemctl status keycloak
```

View logs:
```bash
sudo journalctl -u keycloak
```

### Connection Issues
Verify Nginx configuration:
```bash
sudo nginx -t
```

Check if ports are open:
```bash
sudo ufw status
```

## Upgrading Keycloak
For future upgrades, download the new version and follow a similar installation process, ensuring to back up your configuration and database first.

## Additional Resources
- [Keycloak Official Documentation](https://www.keycloak.org/documentation)
- [Keycloak Server Installation Guide](https://www.keycloak.org/guides#server)
- [Nginx Documentation](https://nginx.org/en/docs/)
- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)