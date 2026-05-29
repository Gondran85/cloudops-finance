# CloudOps Finance — Progress Checklist

> Status of the build across all phases. Updated after the observability +
> documentation session.
> Region: **us-east-1** | Account: 765936999166

---

## Phase 1 — Foundation ✅ COMPLETE

- [x] Root account hardened (MFA on root, no root access keys)
- [x] IAM user `cloudops-admin` (MFA + AdministratorAccess + AWS CLI)
- [x] Budgets: $1, $5, $10 + forecast budget ($20)
- [x] CloudTrail multi-region with log file validation
- [x] S3 bucket `cloudtrail-logs-<account>-cloudops` with MFA-delete-deny policy
- [x] Cost Explorer + Cost Anomaly Detection (threshold $1)
- [x] GitHub repo `cloudops-finance` created (public, MIT)

## Phase 2 — Networking ✅ COMPLETE (validated, 6 tests passed)

- [x] VPC `cloudops-vpc` (10.0.0.0/16)
- [x] 4 subnets: 2 public + 2 private (us-east-1a / us-east-1b)
- [x] Internet Gateway `cloudops-igw` attached
- [x] Route tables: public (route to IGW) + private (local only), associated
- [x] 3 Security Groups, layered, SG-to-SG references (`sg-alb`, `sg-web`, `sg-db`)
- [x] Consistent tags (validated in Tag Editor)

## Phase 3 — Compute, Data & Deployment ✅ COMPLETE

### Part 3A — IAM, storage, database, secrets ✅
- [x] IAM Role `cloudops-ec2-role` (SSM Core + S3 ReadOnly + SecretsManager RW)
- [x] S3 buckets `cloudops-static-...` + `cloudops-uploads-...` (private, versioned, SSE-S3)
- [x] DB Subnet Group (private-subnet-a + b)
- [x] RDS PostgreSQL `cloudops-finance-db` (db.t3.micro, single-AZ, private, no public access)
- [x] Secrets Manager `cloudops/db/credentials` (full connection details)

### Part 3B — Compute, deploy, load balancing ✅
- [x] Security Group `sg-vpce` (inbound 443 from sg-web)
- [x] Interface VPC Endpoints: `ssm`, `ssmmessages`, `ec2messages`, `secretsmanager` (Private DNS on)
- [x] Gateway VPC Endpoint: `s3` (free)
- [x] `sg-web` corrected to **no SSH / no port 22** (SSM-only access)
- [x] Launch Template `cloudops-web-template` (AL2023, **t3.micro**, sg-web, IAM role, IMDSv2 required, NO public IP, NO key pair) — versioned v1 → v2 → v3
- [x] Offline dependency strategy: wheels built in `python:3.9-slim` Docker, stored in S3, installed with `--no-index` (`scripts/build-wheels.sh`)
- [x] `ec2-bootstrap.sh` fixed: offline pip + nginx.conf overwrite (no fragile sed)
- [x] 2 EC2 launched across 2 AZs, zero-touch bootstrap (<1 min to serving)
- [x] DB schema initialized once (`scripts/db-init.sql` — `entries` table)
- [x] ALB `cloudops-alb` + Target Group `cloudops-tg-web` (health check `/health`, 2 healthy targets)
- [x] App verified live through the ALB from the public internet (read + write)
- [x] Demo captured (screenshots + video)
- [x] Teardown executed and verified (ALB deleted, endpoints deleted, EC2/RDS stopped)

## Phase 4 — Observability ✅ COMPLETE

- [x] SNS topic `cloudops-alerts` (Standard) + confirmed email subscription
- [x] 7 CloudWatch alarms: RDS (CPU, storage, connections) + EC2 ×2 (CPU, status check)
- [x] Alarm-to-email path tested end-to-end (`set-alarm-state`)
- [x] CloudWatch dashboard `CloudOpsFinance` as code (`iac/cloudwatch-dashboard.json` + `iac/create-dashboard.sh`)
- [~] WAF — **deliberately deferred** (planned; needs ALB attached; cost)
- [x] Shield Standard — active automatically on the ALB (documented, no action needed)

## Phase 5 — IaC & Polish 🔄 PARTIAL

- [ ] Terraform (`iac/`) reproducing the architecture — **deferred** (studying the tool first)
- [ ] CI lint workflow (`.github/workflows/lint.yml`) — planned
- [ ] `requirements-lock.txt` (pinned transitive deps for reproducible builds) — planned
- [x] `cost-estimate.md` written
- [x] `well-architected-review.md` written
- [x] `README.md` reconciled (implemented vs planned)
- [x] `architecture.md`, `security.md`, `lessons-learned.md` updated through Phase 4
- [x] Demo video recorded (edit/link pending)
- [ ] LinkedIn post — planned

---

## Documentation status

| Document | Status |
|----------|--------|
| README.md | ✅ Reconciled (implemented vs planned) |
| docs/lessons-learned.md | ✅ Phases 1–4 |
| docs/security.md | ✅ Phases 1–4, SSH rule removed |
| docs/architecture.md | ✅ Phases 2–4 |
| docs/cost-estimate.md | ✅ Written |
| docs/well-architected-review.md | ✅ Written |
| scripts/README.md | ✅ Corrected, lists all scripts |
| progress-checklist.md | ✅ This document |

---

## Open items (none blocking, none billing)

- **Screenshots:** Phase 4 captures (dashboard, alarms, SNS) not yet uploaded;
  decide on masking the email address before publishing to the public repo.
- **Diagram:** `diagrams/architecture.png` shows the target vision (incl.
  planned Route 53 / CloudFront / WAF / Lambda); architecture.md notes this.
  Refresh to mark implemented vs planned someday.
- **Roadmap (future phases):** Terraform, CI/CD, HTTPS via ACM/CloudFront,
  WAF, Lambda, RDS Multi-AZ, Auto Scaling Group, Cognito. Costs and rationale
  documented in cost-estimate.md and well-architected-review.md.

---

## Current infrastructure state (between sessions)

- EC2 ×2: **stopped** (restart in ~1 min; zero-touch)
- RDS: **stopped** (auto-starts after 7 days if left)
- ALB + Target Group: **deleted** (recreate in ~5 min)
- Interface VPC Endpoints ×4: **deleted** (recreate in ~5–10 min)
- Everything else (VPC, S3, Secrets Manager, IAM, CloudTrail, Budgets, Launch
  Template, alarms, dashboard): **persistent, ~$0**
