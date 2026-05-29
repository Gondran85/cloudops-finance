# Security

This document captures the security controls applied throughout the
CloudOps Finance project, organized by phase. It distinguishes controls
that are **implemented and verified** from those that are **planned**.

---

## Phase 1 — Foundation

### Identity and Access Management
- **Root user hardened.** MFA enabled, no access keys, strong password in a
  password manager. Used only for billing and account recovery.
- **Dedicated IAM user `cloudops-admin`** for daily operations, with MFA
  enforced and the `AdministratorAccess` managed policy.
- AWS CLI access keys issued to `cloudops-admin` only, never to root.

### Auditing and Compliance
- **Multi-region CloudTrail** capturing management events (read + write) in a
  dedicated S3 bucket.
- **Log file validation** enabled to detect tampering.
- **S3 bucket policy denies object/bucket deletion without MFA**, preventing
  an attacker holding a non-MFA access key from erasing audit evidence.
- Bucket versioning and SSE-S3 encryption on the audit bucket.

### Cost governance (treated as a security control)
Cost surprise is operational risk, so it sits alongside security:
- AWS Budgets at $1, $5, $10, plus a forecasted alert at $20.
- Cost Anomaly Detection monitor with a $1 threshold.
- Cost Explorer activated for retrospective analysis.

### Trade-offs documented
- **SSE-S3 instead of SSE-KMS** for CloudTrail logs, to stay in Free Tier
  (~$1/month). Production would prefer SSE-KMS for granular key control.
- **`AdministratorAccess` on `cloudops-admin`** for development velocity.
  Production would use scoped, service-specific policies.

---

## Phase 2 — Network Security

### Network segmentation
- **Dedicated VPC** (`10.0.0.0/16`), not the default VPC.
- **Tier separation:** ALB in public subnets; EC2 and RDS in private subnets
  with no route to the internet.
- **No public IPs** on application servers — all inbound traffic passes
  through the ALB.

### Layered Security Groups (SG-to-SG references)
A three-tier chain enforces least-privilege network access. Rules reference
other Security Groups as the source, not CIDR ranges (identity-based
segmentation, aligned with Zero Trust):

| SG | Inbound source | Port | Purpose |
|----|----------------|------|---------|
| `sg-alb` | `0.0.0.0/0` | 80 (443 planned) | Accept HTTP from the internet |
| `sg-web` | `sg-alb` | 80 | Accept web traffic only from the ALB |
| `sg-db`  | `sg-web` | 5432 | Accept PostgreSQL only from the web tier |
| `sg-vpce`| `sg-web` | 443 | Accept HTTPS to Interface VPC Endpoints |

> **No SSH anywhere.** There is deliberately no inbound port 22 on any
> Security Group. Administrative access is through AWS Systems Manager
> Session Manager only (see Phase 3). This removes SSH key management and
> the most common brute-force attack surface entirely.

### Routing as a security boundary
- Public route table: default route to the Internet Gateway, associated with
  public subnets only.
- Private route table: local VPC route only (plus the S3 Gateway Endpoint),
  no internet path, associated with private subnets only.

### Trade-offs documented
- **Default NACLs kept allow-all** because Security Groups already enforce
  strict rules. Production would add customized NACLs as a stateless layer.
- **No NAT Gateway** (cost). Outbound to AWS services is via VPC Endpoints;
  there is no general outbound internet path from private subnets — which is
  itself a security benefit (no data-exfiltration "front door").

---

## Phase 3 — Compute, Data, and Secrets

### Instance access and hardening
- **No SSH, no key pair, no port 22.** EC2 instances are reachable only via
  **SSM Session Manager**, authenticated by IAM and fully audited in
  CloudTrail. There is no public entry point to the instances.
- **IMDSv2 required** on the Launch Template, mitigating SSRF-based theft of
  instance credentials from the metadata service.
- Instances run in **private subnets with no public IP**.

### Least-privilege IAM role
- EC2 instances assume `cloudops-ec2-role` with three managed policies:
  `AmazonSSMManagedInstanceCore`, `AmazonS3ReadOnlyAccess`,
  `SecretsManagerReadWrite`.
- **Documented trade-off:** these managed policies are broader than ideal.
  Production would use inline policies scoped to specific resource ARNs
  (e.g. `secretsmanager:GetSecretValue` on the single secret only).

### Secrets management
- Database credentials live in **AWS Secrets Manager**
  (`cloudops/db/credentials`), read at runtime via the instance role.
- **No secrets in code, environment files, or the AMI.** The bootstrap script
  and application source are safe to keep in a public repository.
- Access to Secrets Manager from the private subnet is via a **dedicated
  Interface VPC Endpoint with Private DNS** — credentials never traverse the
  public internet.
- **Documented trade-off:** the RDS password was set manually rather than via
  RDS-managed credentials. Production would use RDS-managed rotation.

### Encryption
- **At rest:** SSE-S3 on all S3 buckets; encryption enabled on RDS.
- **In transit (internal):** application-to-Secrets-Manager and
  application-to-S3 traffic stays on AWS's private network via VPC Endpoints.

### Network isolation of dependencies
- Python dependencies are installed **offline** from pre-built wheels in S3;
  instances never reach PyPI or any public package index. This eliminates a
  supply-chain pathway (no live `pip install` from the internet at boot).

---

## Phase 4 — Observability as Security

Observability is a security control: you cannot respond to what you cannot see.

- **CloudWatch alarms** on RDS (CPU, free storage, connections) and EC2 (CPU,
  status checks). An abnormal connection count, for example, can indicate a
  connection leak or an attack.
- **SNS email notifications**, with the alarm-to-email path tested
  end-to-end (not merely configured).
- **CloudWatch dashboard** for at-a-glance system state.
- **CloudTrail** (from Phase 1) provides the audit trail of every
  administrative action, including every Session Manager connection.

---

## Planned (NOT yet implemented)

These controls appear in the long-term design but are not built yet:

- **HTTPS/TLS via ACM** on the ALB — the listener is currently HTTP only.
  (CloudFront, planned for the edge, would also provide TLS termination.)
- **AWS WAF** with managed rules and rate limiting on the ALB/CloudFront.
- **AWS Shield Standard** is active automatically and free on the ALB; no
  action is required. Shield Advanced is out of scope (cost).
- **Route 53 + CloudFront** for the edge layer.
- **RDS Multi-AZ** (currently single-AZ, Multi-AZ-ready).
- **Scoped inline IAM policies** replacing the broad managed policies.
- **RDS-managed credential rotation** replacing the manually set password.

---

## Summary: implemented vs planned

| Control | Status |
|---------|--------|
| MFA on root + IAM user | ✅ Implemented |
| Multi-region CloudTrail + log validation | ✅ Implemented |
| Private subnets, no public IPs on EC2/RDS | ✅ Implemented |
| Layered SG-to-SG (no SSH anywhere) | ✅ Implemented |
| SSM-only access, IMDSv2 required | ✅ Implemented |
| Secrets Manager + private VPC Endpoint | ✅ Implemented |
| Encryption at rest (S3, RDS) | ✅ Implemented |
| Offline dependency install (no PyPI) | ✅ Implemented |
| CloudWatch alarms + SNS + dashboard | ✅ Implemented |
| AWS Budgets + Cost Anomaly Detection | ✅ Implemented |
| HTTPS/TLS via ACM | 🔲 Planned |
| AWS WAF | 🔲 Planned |
| Route 53 + CloudFront | 🔲 Planned |
| RDS Multi-AZ | 🔲 Planned |
| Scoped inline IAM policies | 🔲 Planned |
