#!/bin/bash
# ============================================================================
# CloudOps Finance — EC2 Bootstrap Script
# ============================================================================
# This script is executed as user_data when an EC2 instance is launched.
# It installs system dependencies, fetches application code from S3, installs
# Python packages, configures Nginx as a reverse proxy, and starts the Flask
# app as a systemd service.
#
# Target OS: Amazon Linux 2023 (ships with Python 3.9)
# Runs as: root
#
# No secrets or endpoints are hardcoded here. The application reads ALL
# database connection details (host, port, dbname, user, password) from
# AWS Secrets Manager at runtime, using the EC2 instance IAM role.
# This file is therefore safe to keep in a public repository.
#
# ---------------------------------------------------------------------------
# NETWORK PREREQUISITES (private subnet, no NAT Gateway):
#   The instance reaches AWS services through VPC Endpoints only. The
#   following endpoints MUST exist in the VPC before launch, or the app
#   will fail:
#     - S3 (Gateway)              -> app code + Python wheels download
#     - SSM, SSMMessages,
#       EC2Messages (Interface)   -> Session Manager access
#     - SecretsManager (Interface, Private DNS enabled) -> DB credentials
#   Without the SecretsManager endpoint, every request hangs ~30s then 500s.
#
# DATABASE SCHEMA:
#   The `entries` table is created once via scripts/db-init.sql, run manually
#   against the RDS instance the first time it is provisioned. It is NOT run
#   from this bootstrap, because multiple instances running the same script
#   would duplicate the non-idempotent sample-data INSERT. DB seeding belongs
#   in a separate one-time migration step. See docs/lessons-learned.md.
#
# DEPENDENCY ARTIFACTS:
#   Python wheels are pre-built for Python 3.9 / manylinux2014_x86_64 inside
#   a python:3.9-slim Docker container and uploaded to S3 under app/wheels/.
#   Building in a matching container guarantees conditional dependencies
#   (e.g. importlib-metadata, greenlet) resolve correctly. See
#   scripts/build-wheels.sh and docs/lessons-learned.md.
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
# Wheels are excluded here -- they are downloaded separately in Section 4
# into their own directory to keep app code and build artifacts isolated.
S3_BUCKET="cloudops-static-765936999166"   # Bucket holds app code and pre-built Python wheels

cd /opt/cloudops
mkdir -p app/src
aws s3 cp "s3://${S3_BUCKET}/app/" /opt/cloudops/app/src/ \
  --recursive \
  --region us-east-1 \
  --exclude "wheels/*"
chown -R cloudops:cloudops /opt/cloudops
cd app/src

# ----------------------------------------------------------------------------
# 4. Install Python dependencies from S3 (offline -- no PyPI access required)
# ----------------------------------------------------------------------------
# The EC2 instance lives in a private subnet with no NAT Gateway, so it cannot
# reach PyPI on the public internet. Python wheels are pre-packaged in S3 and
# installed via --no-index, ensuring deterministic, network-isolated installs.
# This is the "deployment artifact" pattern used in regulated environments.

WHEELS_DIR="/opt/cloudops/wheels"
mkdir -p "$WHEELS_DIR"

echo "Downloading pre-built wheels from S3..."
aws s3 cp "s3://${S3_BUCKET}/app/wheels/" "$WHEELS_DIR/" \
  --recursive \
  --region us-east-1

echo "Creating Python virtual environment..."
python3 -m venv /opt/cloudops/venv

echo "Upgrading pip (offline, from S3 wheels)..."
/opt/cloudops/venv/bin/pip install \
  --no-index \
  --find-links="$WHEELS_DIR" \
  --upgrade pip

echo "Installing application dependencies (offline, from S3 wheels)..."
/opt/cloudops/venv/bin/pip install \
  --no-index \
  --find-links="$WHEELS_DIR" \
  -r /opt/cloudops/app/src/requirements.txt

echo "Python environment ready."

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
# We overwrite the main nginx.conf with a clean version that has NO default
# server block and ends with `include /etc/nginx/conf.d/*.conf;`. This avoids
# fragile in-place edits (a previous sed approach corrupted the file by
# deleting an unbalanced brace on Amazon Linux 2023). See lessons-learned.md.

cat > /etc/nginx/nginx.conf <<'EOF'
# Managed by CloudOps Finance bootstrap. Loads app config from conf.d/.
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log notice;
pid /run/nginx.pid;

include /usr/share/nginx/modules/*.conf;

events {
    worker_connections 1024;
}

http {
    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

    sendfile            on;
    tcp_nopush          on;
    keepalive_timeout   65;
    types_hash_max_size 4096;

    include             /etc/nginx/mime.types;
    default_type        application/octet-stream;

    # Application server block lives here:
    include /etc/nginx/conf.d/*.conf;
}
EOF

# Our application's server block (proxies to gunicorn on 127.0.0.1:5000)
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

# ----------------------------------------------------------------------------
# 7. Enable and start services
# ----------------------------------------------------------------------------
# Validate Nginx config before starting; a syntax error fails the bootstrap
# here with a clear message instead of leaving Nginx half-started.
systemctl daemon-reload
nginx -t
systemctl enable cloudops.service
systemctl enable nginx.service
systemctl start cloudops.service
systemctl start nginx.service

# ----------------------------------------------------------------------------
# 8. Log bootstrap completion
# ----------------------------------------------------------------------------
echo "Bootstrap completed at $(date)" >> /var/log/cloudops/bootstrap.log
