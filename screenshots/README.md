# Screenshots

Visual evidence of the implemented architecture, in chronological build order.
Every image is committed to this folder and referenced by relative path, so the
links never expire.

> Images are uploaded as files (Add file → Upload files), not pasted into the
> editor. Pasted images use temporary signed URLs that expire within minutes.

---

## Phase 2 — Networking

### VPC (10.0.0.0/16)
![VPC creation](01-vpc-creation.jpg)

### Four subnets across two AZs (2 public + 2 private)
![Subnets across two AZs](02-subnets-4-across-2az.jpg)

### Internet Gateway attached
![Internet Gateway attached](03-internet-gateway-attached.jpg)

### Route tables (public + private)
![Route tables](04-route-tables.jpg)

### Private subnet associations
![Private subnet associations](05-private-subnet-associations.jpg)

### Public subnet associations
![Public subnet associations](06-public-subnet-associations.jpg)

### Security Group — ALB tier (HTTP/HTTPS from internet)
![sg-alb](07-sg-alb.jpg)

### Security Group — Database tier (PostgreSQL from web tier only)
![sg-db](08-sg-db.jpg)

---

## Phase 3 — Compute, Data & Deployment

### IAM role for EC2 (SSM + S3 read + Secrets Manager)
![IAM EC2 role](09-iam-ec2-role.jpg)

### S3 buckets (static, uploads, CloudTrail logs)
![S3 buckets](10-s3-buckets.jpg)

### RDS PostgreSQL (db.t3.micro, private)
![RDS PostgreSQL](11-rds-postgresql.jpg)

### Secrets Manager — database credentials
![Secrets Manager](12-secrets-manager.jpg)

### VPC Endpoints (S3 Gateway + SSM/SSMMessages/EC2Messages Interface)
![VPC Endpoints](13-vpc-endpoints.jpg)

### Launch Template created
![Launch Template created](14-launch-template-created.jpg)

### Launch Template details (t3.micro, AL2023, private subnet, SSM)
![Launch Template details](15-launch-template-details.jpg)

### Launch Template versions (v1 → v2 → v3, immutable rollback)
![Launch Template versions](16-launch-template-versions.jpg)

### Launch Template v3 set as default
![Launch Template v3 default](17-launch-template-v3-default.jpg)

### Two instances running across two AZs
![Instances running](18-instances-running.jpg)

### Instances passing 3/3 status checks
![Instances 3/3 checks](19-instances-3checks-passed.jpg)

### SSM Session Manager — shell access with no SSH
![SSM session active](20-ssm-session-active.jpg)

### cloud-init log — the offline-pip problem (PyPI unreachable from private subnet)
![cloud-init pip offline error](21-cloudinit-pip-offline-error.jpg)

### cloud-init log — bootstrap complete in ~52s (nginx OK, services started)
![cloud-init bootstrap complete](22-cloudinit-bootstrap-complete.jpg)

### Target Group (cloudops-tg-web)
![Target Group](23-target-group.jpg)

### Target Group — 2 healthy targets, one per AZ
![Target Group 2 healthy](24-target-group-2healthy.jpg)

### Application Load Balancer — active
![ALB active](25-alb-active.jpg)

### ALB resource map — listener → rule → target group → 2 healthy targets
![ALB resource map](26-alb-resource-map.jpg)

### Application live through the ALB (public URL, HTTP)
![App live via ALB](27-app-live-via-alb.jpg)

> Note: the browser shows "Not secure" — the listener is HTTP only. HTTPS via
> ACM/CloudFront is on the roadmap (see `docs/security.md`).

---

## Phase 4 — Observability

### Seven CloudWatch alarms in OK state (verified via CloudShell)
![CloudWatch alarms OK](28-cloudwatch-alarms-ok.jpg)

### CloudWatch dashboard — CloudOpsFinance (EC2, RDS, alarm status)
![CloudWatch dashboard](29-cloudwatch-dashboard.jpg)

---

## Teardown

### Teardown verified via CLI (EC2 stopped, RDS stopped, Interface endpoints removed)
![Teardown verified](30-teardown-verified.jpg)

---

## Coverage notes

- **Phase 1 (Foundation)** — no screenshots included yet (CloudTrail, Budgets,
  IAM hardening). Documented in `docs/security.md` and `docs/lessons-learned.md`.
- **SNS topic** — the alarm-to-email notification topic (Standard) is not shown
  here; the alarm configuration and OK states are evidenced above. The end-to-end
  email test is documented in `docs/lessons-learned.md` (Phase 4).
- **Security Group — Web tier** — not shown here. SSH (port 22) was removed so
  that access is SSM-only; the remaining HTTP-from-ALB rule is reflected in the
  ALB and target-group evidence above.
