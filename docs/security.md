[security.md](https://github.com/user-attachments/files/27905046/security.md)
# Security

This document captures all security controls applied throughout the **CloudOps Finance** project, organized by phase.

---

## Phase 1 — Foundation

### Identity and Access Management

- **Root user hardened.** MFA enabled, no access keys, strong password stored in a password manager. Used only for billing and account recovery.
- **Dedicated IAM user** `cloudops-admin` for daily operations, with MFA enforced and the `AdministratorAccess` managed policy.
- **AWS CLI access keys** rotated through the `cloudops-admin` user only, never on root.

### Auditing and Compliance

- **Multi-region CloudTrail** capturing management events (read + write) in a dedicated S3 bucket.
- **Log file validation** enabled to detect tampering.
- **S3 bucket policy** denies object and bucket deletion unless MFA is present, preventing an attacker who obtained an access key (without MFA) from erasing audit evidence.
- **Bucket versioning** and **encryption at rest (SSE-S3)** enabled on the audit bucket.

### Cost Governance (as a security control)

Cost surprise is a form of operational risk, so it is treated alongside security:

- **AWS Budgets** at $1, $5, and $10, plus a forecasted alert at $20.
- **Cost Anomaly Detection** monitor with a $1 threshold and individual-alert delivery.
- **Cost Explorer** activated for retrospective analysis.

### Trade-offs documented

- **SSE-S3 instead of SSE-KMS** for CloudTrail log encryption was chosen to stay within Free Tier (~$1/month savings). In a regulated environment, SSE-KMS would be preferred for granular key control and centralized key auditing.
- **AdministratorAccess** policy on `cloudops-admin` accelerates development velocity for a personal project. In production, this would be replaced with scoped, service-specific policies.

---

## Phase 2 — Network Security

### Network segmentation

- **VPC isolation.** The application runs in a dedicated VPC (`10.0.0.0/16`), not the default VPC. The default VPC has open Security Groups and public subnets in every AZ — unsafe for any workload meant to demonstrate professional practices.
- **Tier separation.** Resources are placed in subnets according to their exposure:
  - Public-facing components (ALB) live in public subnets.
  - Application servers and databases live in private subnets, with no route to the internet.
- **No public IPs on application servers.** EC2 instances will be launched without public IPs in Phase 3. All inbound traffic must pass through the ALB.

### Layered Security Groups (SG-to-SG references)

A three-tier Security Group chain enforces least-privilege network access:

| SG | Inbound source | Inbound port | Purpose |
|---|---|---|---|
| `sg-alb` | `0.0.0.0/0` | 80, 443 | Accept HTTP/HTTPS from internet |
| `sg-web` | `sg-alb` | 80 | Accept web traffic only from ALB |
| `sg-web` | My IP | 22 | SSH for emergency debugging (restricted to admin's IP) |
| `sg-db` | `sg-web` | 5432 | Accept PostgreSQL traffic only from web tier |

SG-to-SG references (rather than CIDR ranges) ensure that scope-of-access shrinks automatically as resources are added or removed from each tier. This is identity-based segmentation, aligned with Zero Trust principles.

### Routing as a security boundary

- **Public route table** has a default route (`0.0.0.0/0`) to the Internet Gateway. Associated with public subnets only.
- **Private route table** has only the local VPC route, with no path to the internet. Associated with private subnets only.
- A subnet's "public" or "private" status is determined entirely by its route table association, not by its name.

### Trade-offs documented

- **SSH access in `sg-web`** is restricted to "My IP" as a fallback for emergency debugging. In production, this would be removed entirely and replaced by AWS Systems Manager Session Manager (no inbound ports required).
- **Default NACLs** are kept as allow-all because Security Groups already enforce strict rules. NACLs would be customized in a production environment to add a stateless layer of defense at the subnet level.
- **No NAT Gateway** in Phase 2 (cost optimization). Outbound internet from private subnets, if needed, will be handled via VPC Endpoints (free for S3/DynamoDB) or Systems Manager in Phase 3.

---

## Future phases

- **Phase 3** will add: encryption at rest on RDS and S3, HTTPS/TLS via ACM on the ALB, Secrets Manager for database credentials, IAM Roles with least-privilege policies for EC2 and Lambda.
- **Phase 4** will add: AWS WAF with Managed Rules and rate limiting on the ALB, AWS Shield Standard documentation, CloudWatch alarms for security-relevant events.
