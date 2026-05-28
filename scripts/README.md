# Operational Scripts

Bash scripts for bootstrapping EC2 instances, building dependencies, and
initializing the database for the CloudOps Finance project.

## Files

- **`ec2-bootstrap.sh`** — EC2 user-data script. Installs Python dependencies
  offline from S3 (no PyPI access in the private subnet), configures Nginx as
  a reverse proxy in front of gunicorn, runs the Flask app as a systemd
  service, and starts everything. Zero-touch: from launch to serving traffic
  in under a minute. Requires the VPC Endpoints documented in the script
  header (S3 Gateway; SSM, SSMMessages, EC2Messages, and Secrets Manager
  Interface endpoints).

- **`build-wheels.sh`** — Builds the Python wheels consumed by
  `ec2-bootstrap.sh`. Runs `pip download` inside a `python:3.9-slim` Docker
  container that matches the EC2 runtime exactly, then uploads the wheels to
  `s3://<bucket>/app/wheels/`. Building in a matching container guarantees
  conditional dependencies resolve correctly. Run from the repository root;
  requires Docker and the AWS CLI (CloudShell works).

- **`db-init.sql`** — One-time database schema initialization. Creates the
  `entries` table with `CREATE TABLE IF NOT EXISTS` (safe to re-run) and
  inserts sample data (NOT idempotent — run once against a fresh database).
  Applied manually via `psql`, not from the bootstrap, to avoid duplicate
  seed data across multiple instances.

## Typical workflow

1. Update `src/requirements.txt` if dependencies change.
2. Run `./build-wheels.sh` to rebuild wheels and upload them to S3.
3. Sync application code to S3 (the bootstrap pulls code and wheels from there).
4. Launch instances from the Launch Template — `ec2-bootstrap.sh` runs as
   user-data and brings each instance up unattended.
5. Initialize the database once with `db-init.sql` against the RDS endpoint.
