# Architecture

This document describes the architectural decisions for the CloudOps Finance
project, phase by phase. It distinguishes what is **implemented** from what is
**planned** (see the final section).

---

## Phase 2 — Networking

### Decision: VPC with CIDR 10.0.0.0/16
A dedicated VPC was created instead of using the default VPC. The default VPC
has implicit configurations (public subnets in every AZ, open security groups)
that are inappropriate for any project meant to demonstrate professional
practices. The CIDR `10.0.0.0/16` provides ~65,000 addresses (RFC 1918 private
space) — far more than this workload needs, with room to grow.

### Decision: Four subnets across two Availability Zones

| Subnet | CIDR | AZ | Tier |
|--------|------|----|----|
| public-subnet-a | 10.0.1.0/24 | us-east-1a | Public |
| public-subnet-b | 10.0.2.0/24 | us-east-1b | Public |
| private-subnet-a | 10.0.10.0/24 | us-east-1a | Private |
| private-subnet-b | 10.0.11.0/24 | us-east-1b | Private |

**Why two AZs?** High availability. If one AZ fails entirely (which has
happened in AWS history), the application keeps serving from the other. The
ALB and RDS Multi-AZ both require at least two AZs.

**Why /24 subnets?** 251 usable IPs each — ample for this scale, with readable
round numbering.

### Decision: Public vs private separation
- **Public subnets** host the ALB (must be internet-facing); they route to the
  Internet Gateway.
- **Private subnets** host EC2 and RDS; they have no direct internet route, so
  a compromised server cannot easily exfiltrate data through the front door.

### Decision: Layered Security Groups
Security Groups reference each other rather than CIDR blocks:

```
Internet (0.0.0.0/0) → [sg-alb :80] → [sg-web :80] → [sg-db :5432]
                                          ↑
                              [sg-vpce :443] ← sg-web
```

Benefits over CIDR rules: dynamic membership (new instances in `sg-web`
inherit access automatically) and tighter scope (only resources explicitly in
`sg-web` can reach the database).

### Trade-offs
- **No NAT Gateway** (~$32/month saved). Private resources reach AWS services
  via VPC Endpoints (Phase 3) instead.
- **No IPv6** — complexity without benefit at this stage.

---

## Phase 3 — Compute, Data, and Deployment

### Decision: EC2 in private subnets, fronted by an ALB
Two `t3.micro` instances run in the private subnets, one per AZ. They have no
public IP. The only way in is the Application Load Balancer in the public
subnets, which forwards traffic to the instances on port 80.

```
Internet → ALB (public subnets) → EC2 web-a / web-b (private subnets)
                                       → Nginx :80 → gunicorn :5000 → Flask
```

**Why an ALB in front of two instances?** Distributes traffic, performs health
checks on `/health`, and tolerates the loss of an entire AZ. The health check
targets `/health` (a static liveness check) rather than `/` (which queries the
database), so a database hiccup does not mark healthy processes as down.

### Decision: Zero-touch provisioning via Launch Template
A versioned Launch Template carries the AMI (Amazon Linux 2023), instance type
(`t3.micro`), the instance IAM role, the `sg-web` security group, **IMDSv2
required**, **no SSH key pair**, and the bootstrap script as user-data. Launching
an instance from the template brings it from boot to serving traffic in under a
minute with no manual steps. Each fix during development became a new immutable
template version (v1 → v2 → v3), giving one-click rollback.

### Decision: Private connectivity via VPC Endpoints (no NAT)
Because there is no NAT Gateway, the private instances reach AWS services
through VPC Endpoints only:

| Endpoint | Type | Purpose | Cost |
|----------|------|---------|------|
| S3 | Gateway | App code + Python wheels download | Free |
| SSM, SSMMessages, EC2Messages | Interface | Session Manager access | ~$0.01/h each |
| Secrets Manager | Interface | DB credentials at runtime | ~$0.01/h |

The S3 Gateway Endpoint is free and always-on; the Interface Endpoints bill per
hour and are created only during active sessions.

### Decision: Offline dependency installation (deployment-artifact pattern)
The private subnet cannot reach PyPI (public internet, no NAT). Rather than add
a NAT Gateway (recurring cost) or expose the instances (security risk), Python
wheels are pre-built in a `python:3.9-slim` Docker container that matches the
EC2 runtime, uploaded to S3, and installed offline with
`pip install --no-index --find-links`. Building in a matching container is what
makes conditional dependencies resolve correctly — the core reason for hermetic
builds. (Full story in `lessons-learned.md`, Phase 3.)

### Decision: Data tier — RDS PostgreSQL + Secrets Manager
- **RDS `db.t3.micro`**, single-AZ, in the private subnets, no public access.
  The design is **Multi-AZ-ready**: enabling Multi-AZ is a one-click toggle
  with no application change. Single-AZ is a cost decision for the demo, made
  explicit rather than hidden.
- **Credentials in Secrets Manager**, read at runtime via the instance role and
  the Secrets Manager VPC Endpoint. Nothing sensitive is hardcoded; the app
  builds its database URL entirely from the secret.
- **S3 buckets** (app code + wheels, and uploads), private, versioned, SSE-S3.

---

## Phase 4 — Observability

### Decision: Alarms + notifications + dashboard
- **Seven CloudWatch alarms**: RDS (CPU, free storage, connections) and each
  EC2 instance (CPU, status check). Per-instance rather than aggregate, so an
  alert identifies *which* instance is affected.
- **SNS** delivers alarm notifications by email. The notification path was
  tested end-to-end by forcing an alarm state, not merely configured.
- **A CloudWatch dashboard**, defined declaratively in JSON
  (`iac/cloudwatch-dashboard.json`) and applied with an idempotent
  `put-dashboard` wrapper, consolidates EC2, RDS, and alarm status on one
  screen. Metric math converts raw bytes to GB/MB for readability.

This is observability as both an operational and a security control: an
abnormal connection count or a status-check failure surfaces immediately.

---

## Implemented vs planned

**Implemented:** VPC + subnets + IGW + route tables; layered Security Groups;
ALB (HTTP); 2× EC2 `t3.micro` multi-AZ, zero-touch via Launch Template; RDS
PostgreSQL single-AZ; S3; Secrets Manager; VPC Endpoints (S3, SSM x3, Secrets
Manager); CloudWatch alarms + dashboard; SNS; CloudTrail; AWS Budgets.

**Planned (not yet built):**
- **Edge:** Route 53 (DNS) + CloudFront (CDN, also provides TLS)
- **HTTPS/TLS** via ACM on the ALB (currently HTTP only)
- **WAF** (managed rules, rate limiting)
- **Lambda** for S3 receipt-upload processing
- **RDS Multi-AZ** promotion
- **Infrastructure as Code** (Terraform) to replace Console + script provisioning
- **CI/CD** (GitHub Actions), **Docker/ECS**, **Cognito**, **Auto Scaling Group**

> **Note on the diagram.** `diagrams/architecture.png` currently shows the
> full target architecture, including planned components (Route 53, CloudFront,
> WAF, Lambda). It represents the vision, not the current build; the prose
> above is the source of truth for what is implemented today.

---

## Provisioning order (current, manual)

1. Foundation: IAM, MFA, Budgets, CloudTrail (Phase 1)
2. Networking: VPC, subnets, IGW, route tables, Security Groups (Phase 2)
3. IAM role, S3 buckets, RDS, Secrets Manager (Phase 3A)
4. VPC Endpoints (S3 Gateway; SSM x3, Secrets Manager Interface)
5. Build + upload wheels (`scripts/build-wheels.sh`); sync app code to S3
6. Launch Template; launch 2 EC2 (zero-touch bootstrap)
7. Initialize DB schema once (`scripts/db-init.sql`)
8. ALB + Target Group
9. Observability: SNS, alarms, dashboard (`iac/create-dashboard.sh`)
10. Teardown when idle (see `demo-teardown-checklist.md`)
