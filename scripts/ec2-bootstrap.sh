#!/bin/bash
# ============================================================================
# CloudOps Finance — EC2 Bootstrap Script
# ============================================================================
# This script is executed as user_data when an EC2 instance is launched.
# It installs system dependencies, fetches application code from S3, installs
# Python packages, configures Nginx as a reverse proxy, and starts the Flask
# app as a systemd service.
#
# Target OS: Amazon Linux 2023
# Runs as: root
#
# No secrets or endpoints are hardcoded here. The application reads ALL
# database connection details (host, port, dbname, user, password) from
# AWS Secrets Manager at runtime, using the EC2 instance IAM role.
# This file is therefore safe to keep in a public repository.
# ============================================================================

set -euxo pipefail

# ----------------------------------------------------------------------------
# 1. Update system and install OS packages
# ----------------------------------------------------------------------------
dnf update -y
dnf install -y python3 python3-pip nginx postgresql15

# ----------------------------------------------------------------------------
# 2. Create application directory and user
# ----------------------------------------------------------------------------
useradd --system --create-home --shell /usr/sbin/nologin cloudops || true
mkdir -p /opt/cloudops
chown -R cloudops:cloudops /opt/cloudops

# ----------------------------------------------------------------------------
# 3. Fetch application code from S3 (no internet egress required)
# ----------------------------------------------------------------------------
# Code is versioned in GitHub but deployed via S3, so the private instance
# never needs a route to the internet. The S3 Gateway VPC Endpoint is free.
S3_BUCKET="cloudops-static-765936999166"   # replace ACCOUNTID with your account number
cd /opt/cloudops
mkdir -p app/src
aws s3 cp "s3://${S3_BUCKET}/app/" /opt/cloudops/app/src/ --recursive --region us-east-1
chown -R cloudops:cloudops /opt/cloudops
cd app/src

# ----------------------------------------------------------------------------
# 4. Install Python dependencies in a virtual environment
# ----------------------------------------------------------------------------
python3 -m venv /opt/cloudops/venv
/opt/cloudops/venv/bin/pip install --upgrade pip
/opt/cloudops/venv/bin/pip install -r /opt/cloudops/app/src/requirements.txt

# ----------------------------------------------------------------------------
# 5. Configure Flask as a systemd service
# ----------------------------------------------------------------------------
# Only non-sensitive config here. Host/port/dbname/user/password all come
# from the secret named below, resolved by the app at runtime.
cat > /etc/systemd/system/cloudops.service <<'EOF'
[Unit]
Description=CloudOps Finance Flask Application
After=network.target

[Service]
Type=simple
User=cloudops
Group=cloudops
WorkingDirectory=/opt/cloudops/app/src
Environment="AWS_REGION=us-east-1"
Environment="DB_SECRET_NAME=cloudops/db/credentials"
ExecStart=/opt/cloudops/venv/bin/gunicorn --bind 127.0.0.1:5000 --workers 2 app:app
Restart=on-failure
RestartSec=5
StandardOutput=append:/var/log/cloudops/app.log
StandardError=append:/var/log/cloudops/error.log

[Install]
WantedBy=multi-user.target
EOF

mkdir -p /var/log/cloudops
chown -R cloudops:cloudops /var/log/cloudops

# ----------------------------------------------------------------------------
# 6. Configure Nginx as a reverse proxy on port 80
# ----------------------------------------------------------------------------
cat > /etc/nginx/conf.d/cloudops.conf <<'EOF'
server {
    listen 80 default_server;
    server_name _;

    access_log /var/log/nginx/cloudops-access.log;
    error_log /var/log/nginx/cloudops-error.log;

    location /health {
        access_log off;
        proxy_pass http://127.0.0.1:5000/health;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

# Remove default Nginx server block
sed -i '/^[[:space:]]*server {/,/^[[:space:]]*}/d' /etc/nginx/nginx.conf || true

# ----------------------------------------------------------------------------
# 7. Enable and start services
# ----------------------------------------------------------------------------
systemctl daemon-reload
systemctl enable cloudops.service
systemctl enable nginx.service
systemctl start cloudops.service
systemctl start nginx.service

# ----------------------------------------------------------------------------
# 8. Log bootstrap completion
# ----------------------------------------------------------------------------
echo "Bootstrap completed at $(date)" >> /var/log/cloudops/bootstrap.log
