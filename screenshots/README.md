# Screenshots

Visual evidence of the implemented architecture, in chronological build order.
Every image is committed to this folder and referenced by relative path, so the
links never expire.

> Images are uploaded as files (Add file → Upload files), not pasted into the
> editor. Pasted images use temporary signed URLs that expire within minutes.

---

## Phase 2 — Networking

### VPC (10.0.0.0/16)
![VPC creation](02-Screenshot_Criacao_VPC.jpg)

### Four subnets across two AZs (2 public + 2 private)
![Subnets across two AZs](03-Screenshot_Criacao_de_4_subnet_publicas_e_privadas_em_2_az.jpg)

### Internet Gateway attached
![Internet Gateway attached](04-Screenshot_Internet_Gateway_Attached.jpg)

### Route tables (public + private)
![Route tables](05-Screenshot_Route_Tables.jpg)

### Private subnet associations
![Private subnet associations](06-Screenshot_Subnet_Associate_Private_subnets.jpg)

### Public subnet associations
![Public subnet associations](07-Screenshot_Subnet_Associate_Public_subnets.jpg)

### Security Group — ALB tier (HTTP/HTTPS from internet)
![sg-alb](08-Screenshot_SecurtyGroup-alb-cloudops-vpc.jpg)

### Security Group — Database tier (PostgreSQL from web tier only)
![sg-db](10-Screenshot_SecurityGroup-database-cloudops-vpc.jpg)

---

## Phase 3 — Compute, Data & Deployment

### IAM role for EC2 (SSM + S3 read + Secrets Manager)
![IAM EC2 role](09-Screenshot_criacao_de_3_roles.jpg)

### S3 buckets (static, uploads, CloudTrail logs)
![S3 buckets](10_-Screenshot_criacao_de_2_bucket_static_e_uploads.jpg)

### RDS PostgreSQL (db.t3.micro, private)
![RDS PostgreSQL](11-Screenshot_criacao_RDS_database.jpg)

### Secrets Manager — database credentials
![Secrets Manager](12-Screenshot_criacao_da_credenciais_Secrets_do_Database_.jpg)

### VPC Endpoints (S3 Gateway + SSM/SSMMessages/EC2Messages Interface)
![VPC Endpoints](13-Screenshot_4_Enpoint_VPC_.jpg)

### Launch Template created
![Launch Template created](14-Screenshot_Launch_instance.jpg)

### Launch Template details (t3.micro, AL2023, private subnet, SSM)
![Launch Template details](14-Screenshot_launch_template_parte_2.jpg)

### Launch Template versions (v1 → v2 → v3, immutable rollback)
![Launch Template versions](21-_Screenshot_Launch_Template_Versions.jpg)

### Launch Template v3 set as default
![Launch Template v3 default](21-_Screenshot_Launch_Template_V3.jpg)

### Two instances running across two AZs
![Instances running](15-Screenshot_2_Instances_from_Launch_Templates.jpg)

### Instances passing 3/3 status checks
![Instances 3/3 checks](19-Screenshot_2_New_Instances.jpg)

### SSM Session Manager — shell access with no SSH
![SSM session active](16-Screenshot_ssm_running.jpg)

### cloud-init log — the offline-pip problem (PyPI unreachable from private subnet)
![cloud-init pip offline error](22-_Screenshot_Session_Manager_EC2_-__cloud-init_zero-touch_.jpg)

### Target Group (cloudops-tg-web)
![Target Group](18-Screenshot_Target_Group.jpg)

### Target Group — 2 healthy targets, one per AZ
![Target Group 2 healthy](18-Screenshot_Target_Group_Dashboard.jpg)

### Application Load Balancer — active
![ALB active](17-Screenshot_LoadBalancer.jpg)

### ALB resource map — listener → rule → target group → 2 healthy targets
![ALB resource map](17-Screenshot_LoadBalancer_Resource_Map_.jpg)

### Application live through the ALB (public URL, HTTP)
![App live via ALB](20-Screenshot_Website_Full_with_URL_and_Dashboard.jpg)

> Note: the browser shows "Not secure" — the listener is HTTP only. HTTPS via
> ACM/CloudFront is on the roadmap (see `docs/security.md`).

---

## Phase 4 — Observability

### Seven CloudWatch alarms in OK state (verified via CloudShell)
![CloudWatch alarms OK](24-Screenshot_DescribeAlarms_on_CloudShell.jpg)

### CloudWatch dashboard — CloudOpsFinance (EC2, RDS, alarm status)
![CloudWatch dashboard](25-Screenshot_CloudWatch_Dashboard_-_CloudOpsFinance_.jpg)

---

## Teardown

### Teardown verified via CLI (EC2 stopped, RDS stopped, Interface endpoints removed)
![Teardown verified](26-Screenshot_Teardown_Instances_and_Database.jpg)

---

## Coverage notes

- **Phase 1 (Foundation)** — no screenshots included (CloudTrail, Budgets, IAM
  hardening). Documented in `docs/security.md` and `docs/lessons-learned.md`.
- **SNS topic** — the alarm-to-email notification topic (Standard) is not shown
  here; the alarm configuration and OK states are evidenced above. The end-to-end
  email test is documented in `docs/lessons-learned.md` (Phase 4).
- **Security Group — Web tier** — not shown here. SSH (port 22) was removed so
  access is SSM-only; the remaining HTTP-from-ALB rule is reflected in the ALB
  and target-group evidence above.
