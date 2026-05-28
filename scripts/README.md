# Operational Scripts

Bash scripts for bootstrapping EC2 instances, deploying updates, and tearing down resources.

## Files

- **`ec2-bootstrap.sh`** — EC2 user-data script. Installs dependencies offline
  from S3, configures Nginx + gunicorn + systemd, starts the Flask app.
  Zero-touch: launch to serving traffic in under a minute.
- **`db-init.sql`** — One-time schema creation for the `entries` table
  (idempotent CREATE; non-idempotent seed data — run once).
- **`build-wheels.sh`** — Builds Python wheels in a Python 3.9 container
  matching the EC2 runtime, then uploads them to S3 for offline install.
