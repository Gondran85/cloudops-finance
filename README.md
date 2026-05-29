# 🏗️ CloudOps Finance

> Multi-tier, highly available web application on AWS, designed following the **AWS Well-Architected Framework**.

![AWS](https://img.shields.io/badge/AWS-Cloud-FF9900?logo=amazon-aws&logoColor=white)
![Python](https://img.shields.io/badge/Python-3.9-3776AB?logo=python&logoColor=white)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-15-336791?logo=postgresql&logoColor=white)
![Well-Architected](https://img.shields.io/badge/AWS-Well--Architected-232F3E?logo=amazon-aws&logoColor=white)
![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)
![Status: In Progress](https://img.shields.io/badge/Status-In%20Progress-blue)

---

## 📋 About the project

**CloudOps Finance** is a personal finance web application where users record income and expenses and view their balance. The point of this project is **not the app itself** — it is to demonstrate a **professional cloud architecture**: high availability across two Availability Zones, layered security, observability, and cost governance, all running within (or close to) the AWS Free Tier.

### 🎯 Simulated business problem

A fintech needs a resilient, secure, near-zero-cost web MVP to validate user demand for a budget-tracking feature before investing in a full product.

> **Honesty note on scope.** This README separates what is **implemented and verified** from what is **planned**. Everything under "Implemented" has been built and tested in a real AWS account; everything under "Planned / roadmap" is intended future work, not yet built. This separation is deliberate — a portfolio should be auditable, not aspirational-as-if-done.

---

## ✅ Implemented (built and verified)

**Networking**
- Custom VPC (`10.0.0.0/16`), 4 subnets across 2 AZs (2 public, 2 private)
- Internet Gateway, route tables, three-tier Security Groups (ALB → Web → DB) using SG-to-SG references
- **No NAT Gateway** — private instances reach AWS services through VPC Endpoints only

**Compute & deployment**
- 2× EC2 `t3.micro` across two AZs, in private subnets, behind an Application Load Balancer
- Launch Template (versioned) with IMDSv2 required, **no SSH key pair**, access only via SSM Session Manager
- Fully **zero-touch bootstrap**: launch to serving traffic in under a minute, no manual steps
- Flask app served by gunicorn behind Nginx, managed as a systemd service
- Python dependencies installed **offline from S3** (deployment-artifact pattern) — no PyPI access in the private subnet

**Data**
- RDS PostgreSQL `db.t3.micro` (single-AZ, private, no public access)
- Credentials stored in AWS Secrets Manager, read at runtime via the EC2 IAM role
- S3 buckets (app code + pre-built wheels + uploads), private, versioned, SSE-S3

**Connectivity (private)**
- VPC Endpoints: S3 (Gateway, free); SSM, SSMMessages, EC2Messages, Secrets Manager (Interface, Private DNS enabled)

**Observability**
- CloudWatch: 7 alarms (RDS CPU/storage/connections, EC2 CPU/status per instance) + a JSON-defined dashboard
- SNS email notifications; alarm-to-email path tested end-to-end with `set-alarm-state`

**Audit & governance**
- Multi-region CloudTrail with log file validation
- AWS Budgets (3 thresholds) + Cost Anomaly Detection

---

## 🔲 Planned / roadmap (NOT yet built)

These appear in the long-term architecture vision but are **not** implemented yet:

- **Edge:** Route 53 (DNS) + CloudFront (CDN) — not provisioned
- **HTTPS/TLS:** ACM certificate on the ALB — currently HTTP only
- **WAF** (managed rules, rate limiting) — not provisioned
- **Lambda** for S3 receipt-upload processing — not provisioned
- **RDS Multi-AZ** — currently single-AZ; the design is "Multi-AZ-ready" (one-click toggle, no app change)
- **Infrastructure as Code (Terraform)** — currently provisioned via Console + scripts
- **CI/CD** (GitHub Actions), **Docker/ECS**, **Cognito**, **Auto Scaling Group** — future phases

> **Shield Standard** is the one edge item that *is* active — because it is enabled automatically and free on every ALB. No action was required.

---

## 🛠️ Technologies and services

**Cloud (AWS), implemented:** VPC · EC2 · RDS PostgreSQL · S3 · ALB · IAM · Secrets Manager · VPC Endpoints · CloudWatch · SNS · CloudTrail · AWS Budgets · Shield Standard

**Application:** Python 3.9 · Flask · SQLAlchemy · gunicorn · HTML5 · CSS3

**Tooling:** Bash · Amazon Linux 2023 · Nginx · Docker (for hermetic wheel builds) · Git · GitHub

> Python 3.9 is the default runtime on Amazon Linux 2023; the project uses the platform default rather than installing a newer interpreter. This choice drove the offline dependency strategy documented in `docs/lessons-learned.md`.

---

## 🏛️ Architecture

![Architecture diagram](diagrams/architecture.png)

Implemented **3-tier, multi-AZ pattern**:

- **Presentation:** Application Load Balancer in public subnets (HTTP)
- **Application:** 2× EC2 `t3.micro` across two AZs, in private subnets (no public IP, no SSH)
- **Data:** RDS PostgreSQL (single-AZ, Multi-AZ-ready) + S3
- **Private connectivity:** VPC Endpoints for S3, SSM, and Secrets Manager (no NAT Gateway)
- **Observability:** CloudWatch alarms + dashboard, SNS notifications
- **Audit & governance:** multi-region CloudTrail, AWS Budgets, Cost Anomaly Detection

📄 Full details in [docs/architecture.md](docs/architecture.md).

---

## 🚀 How to run

### Prerequisites
- AWS account with MFA enabled
- AWS CLI v2 configured
- Docker (to build Python wheels) — CloudShell works

### Provisioning (manual via AWS Console + scripts)

```bash
# 1. Clone the repository
git clone https://github.com/Gondran85/cloudops-finance.git
cd cloudops-finance

# 2. Build and upload Python wheels for offline install
./scripts/build-wheels.sh

# 3. Sync application code to S3 (the bootstrap pulls code + wheels from there)

# 4. Create the required VPC Endpoints (S3 Gateway; SSM, SSMMessages,
#    EC2Messages, Secrets Manager Interface with Private DNS enabled)

# 5. Launch instances from the Launch Template — scripts/ec2-bootstrap.sh
#    runs as user_data and brings each instance up unattended

# 6. Initialize the database schema once
psql -h <RDS_ENDPOINT> -U <DB_USER> -d cloudops -f scripts/db-init.sql

# 7. Create the CloudWatch dashboard
./iac/create-dashboard.sh
```

Step-by-step guidance is in [docs/architecture.md](docs/architecture.md).

### Teardown (important — some resources bill while running)

The ALB and the Interface VPC Endpoints bill per hour. Stop EC2/RDS and delete the ALB and Interface endpoints when not in use. See [docs/demo-teardown-checklist.md](docs/demo-teardown-checklist.md).

---

## 📸 Evidence (screenshots)

See [screenshots/](screenshots/) for the live dashboard, the application served through the ALB, healthy load-balancer targets, the versioned Launch Template, and zero-touch bootstrap logs.

🎥 **Demo video:** recorded; link to be added.

---

## 💰 Cost

Built to run within the Free Tier where possible. EC2 `t3.micro` and RDS `db.t3.micro` are Free-Tier eligible. The two recurring costs are the **ALB** (~$0.022/h) and the **Interface VPC Endpoints** (~$0.01/h each) — both created only during active sessions and removed afterward.

📄 Detailed breakdown and a real-world note on **forecast vs actual cost** in [docs/cost-estimate.md](docs/cost-estimate.md).

---

## 🛡️ Security applied (implemented)

- **Least-privilege IAM** instance role (SSM + S3 read + Secrets Manager)
- **MFA enforced** on human users; root sealed
- **Private subnets** for EC2 and RDS (no public IPs)
- **No SSH** — access via SSM Session Manager only; IMDSv2 required
- **Layered Security Groups** (ALB → Web → DB) using SG-to-SG references
- **Secrets Manager** for DB credentials (no secrets in code or env files)
- **Encryption at rest** on RDS and S3 (SSE-S3)
- **Multi-region CloudTrail** with log file validation
- **AWS Budgets + Cost Anomaly Detection**

Planned (not yet built): HTTPS/TLS via ACM, WAF managed rules.

📄 Full details in [docs/security.md](docs/security.md).

---

## 🏗️ Well-Architected Framework mapping

A full review against the six pillars — covering both what is implemented and the gaps — is in [docs/well-architected-review.md](docs/well-architected-review.md).

---

## 🎓 Lessons learned

Documented at the end of every phase, including the offline-dependency saga, the hermetic Docker wheel build, the Nginx config fix, the Secrets Manager VPC Endpoint, observability setup, and a FinOps note on forecast vs actual cost.

📄 See [docs/lessons-learned.md](docs/lessons-learned.md).

---

## 🔮 Future improvements

- [ ] Migrate the stack to **Terraform** (IaC)
- [ ] HTTPS via **ACM** + **Route 53** + **CloudFront**
- [ ] **WAF** with managed rules and rate limiting
- [ ] **Lambda** for S3 receipt processing
- [ ] **RDS Multi-AZ** for production-grade availability
- [ ] CI/CD with **GitHub Actions**
- [ ] Containerize with **Docker** + **ECS Fargate**
- [ ] **Cognito** for user authentication
- [ ] **Auto Scaling Group** with dynamic policies
- [ ] Pin transitive dependencies (`requirements-lock.txt`) for fully reproducible builds

---

## 👤 Author

**Jefferson Santos Gondran** — Aspiring Cloud Engineer

🔗 [LinkedIn](https://linkedin.com/in/jefferson-santos-2136b2264)

---

## 📄 License

MIT — see [LICENSE](LICENSE).
