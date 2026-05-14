# 🏗️ CloudOps Finance

> Multi-tier, highly available web application on AWS, designed following the **AWS Well-Architected Framework**.

[![AWS](https://img.shields.io/badge/AWS-Cloud-FF9900?logo=amazon-aws&logoColor=white)](https://aws.amazon.com/)
[![Python](https://img.shields.io/badge/Python-3.11-3776AB?logo=python&logoColor=white)](https://python.org)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-15-336791?logo=postgresql&logoColor=white)](https://postgresql.org)
[![Well-Architected](https://img.shields.io/badge/AWS-Well--Architected-232F3E?logo=amazon-aws&logoColor=white)](https://aws.amazon.com/architecture/well-architected/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Status: In Progress](https://img.shields.io/badge/Status-In%20Progress-blue)]()

---

## 📋 About the project

**CloudOps Finance** is a personal finance web application where users register income and expenses and visualize their budget. The goal of this project is **not the app itself** — it is to demonstrate a **professional cloud architecture**: high availability across two Availability Zones, layered security, observability, and cost governance, all running within the AWS Free Tier.

### 🎯 Simulated business problem
A fintech needs a resilient, secure, and inexpensive (near-zero cost) web MVP to validate user demand for a budget-tracking feature before investing in a full product.

### 🛠️ Technologies and services

**Cloud (AWS):** VPC · EC2 · RDS PostgreSQL · S3 · ALB · IAM · Secrets Manager · Lambda · CloudWatch · CloudTrail · SNS · WAF · Shield Standard · AWS Budgets

**Application:** Python 3.11 · Flask · SQLAlchemy · HTML5 · CSS3 · JavaScript (vanilla)

**Tooling and infrastructure:** Bash · Linux (Amazon Linux 2023) · Nginx · Git · GitHub Actions · draw.io

---

## 🏛️ Architecture

![Architecture diagram](diagrams/architecture.png)

The solution implements a classic **3-tier, multi-AZ pattern**:

- **Edge layer:** Route 53 + CloudFront (global DNS and caching) + WAF + Shield Standard
- **Presentation layer:** Application Load Balancer in public subnets
- **Application layer:** 2× EC2 t2.micro across two AZs, in private subnets
- **Data layer:** RDS PostgreSQL (Multi-AZ ready) + S3
- **Serverless:** Lambda processes receipt uploads from S3
- **Observability:** CloudWatch + SNS for alarms and notifications
- **Audit:** Multi-region CloudTrail capturing management events
- **Governance:** AWS Budgets + Cost Anomaly Detection

📄 Full details in [docs/architecture.md](docs/architecture.md).

---

## 🚀 How to run

### Prerequisites
- AWS account with MFA enabled
- AWS CLI v2 configured
- Git installed locally

### Provisioning (manual via AWS Console)
```bash
# 1. Clone the repository
git clone https://github.com/YOUR_USERNAME/cloudops-finance.git
cd cloudops-finance

# 2. Follow the step-by-step guide in docs/architecture.md
# 3. Use scripts/ec2-bootstrap.sh as user_data when launching EC2
# 4. Initialize the database
psql -h <RDS_ENDPOINT> -U admin -d cloudops < scripts/db-init.sql
```

### Provisioning (Terraform — optional, Phase 5)
```bash
cd iac
terraform init
terraform plan
terraform apply
```

### Teardown (important to avoid charges!)
```bash
bash scripts/teardown.sh
# or: terraform destroy
```

---

## 📸 Evidence (screenshots)

*(Screenshots will be added as the project progresses.)*

🎥 **Demo video:** *(Loom link will be added at the end of the project)*

---

## 💰 Cost estimate

| Service | Free Tier | Cost beyond Free Tier (estimate) |
|---|---|---|
| EC2 t2.micro (24/7) | 750h/month free (12 months) | $0 |
| RDS db.t3.micro | 750h/month free (12 months) | $0 |
| ALB | **Not Free Tier** | ~$16/month if running 24/7 |
| WAF | **Not Free Tier** | ~$5-7/month if active full month |
| Lambda | 1M requests/month free (always) | $0 |
| CloudTrail (management events) | Free | $0 |
| Shield Standard | Free | $0 |
| S3 (5 GB) | 5 GB free (12 months) | $0 |
| CloudWatch | 10 alarms + 5 GB logs free | $0 |
| **Monthly total (all running 24/7)** | | **~$22** |
| **Monthly total (ALB/WAF only during demos, ~10h/month)** | | **~$0.30** |

📄 Detailed breakdown in [docs/cost-estimate.md](docs/cost-estimate.md).

---

## 🛡️ Security applied

✅ **Principle of least privilege** on all IAM Roles
✅ **MFA enforced** for human users
✅ **Private subnets** for EC2 and RDS (no public IPs)
✅ **Layered Security Groups** (ALB → Web → DB)
✅ **Secrets Manager** for database credentials (no secrets in code)
✅ **Encryption at rest** enabled on RDS and S3
✅ **HTTPS/TLS** via ACM on the ALB
✅ **Multi-region CloudTrail** with log file validation
✅ **AWS WAF** with Managed Rules and rate limiting
✅ **AWS Shield Standard** active (L3/L4 DDoS protection)
✅ **AWS Budgets + Cost Anomaly Detection** monitoring costs

📄 Full details in [docs/security.md](docs/security.md).

---

## 🏗️ Mapping to the Well-Architected Framework's six pillars

| Pillar | How it is applied in this project |
|---|---|
| **Operational Excellence** | CloudWatch dashboards, CloudTrail, structured logs, version-controlled scripts |
| **Security** | Least-privilege IAM, private subnets, Secrets Manager, WAF, Shield, CloudTrail |
| **Reliability** | Multi-AZ, ALB health checks, RDS Multi-AZ, automated backups |
| **Performance Efficiency** | Right-sizing (t2.micro / t3.micro), CloudFront caching, Lambda autoscaling |
| **Cost Optimization** | Free Tier first, Budgets, cost-allocation tags, Lambda pay-per-use |
| **Sustainability** | Right-sizing, resources powered down when idle, Lambda zero-idle compute |

📄 Full review in [docs/well-architected-review.md](docs/well-architected-review.md).

---

## 🎓 Lessons learned

Updated at the end of every project phase.

📄 See [docs/lessons-learned.md](docs/lessons-learned.md).

---

## 🔮 Future improvements

- [ ] Migrate the entire stack to **Terraform**
- [ ] CI/CD with **GitHub Actions** + AWS CodeDeploy
- [ ] Containerize the application with **Docker** + ECS Fargate
- [ ] Add **Cognito** for real user authentication
- [ ] Implement **Auto Scaling Group** with dynamic policies
- [ ] Custom metrics with **CloudWatch Embedded Metric Format**
- [ ] Integrate CloudTrail with **GuardDuty** and **Security Hub**

---

## 👤 Author

**Jefferson Santos Gondran** — Aspiring Cloud Engineer
- 🔗 [LinkedIn](https://linkedin.com/in/jefferson-santos-2136b2264)
- 📧 gondran.jefferson@gmail.com

---

## 📄 License

MIT — see [LICENSE](LICENSE).
