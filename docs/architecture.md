# Architecture

This document describes the architectural decisions for the **CloudOps Finance** project, starting with the networking foundation.

---

## Phase 2 — Networking

### Decision: VPC with CIDR 10.0.0.0/16

A dedicated VPC was created instead of using the default VPC. The default VPC has implicit configurations (public subnets in every AZ, open security groups) that are inappropriate for any project meant to demonstrate professional practices.

The CIDR `10.0.0.0/16` provides ~65,000 IP addresses, which is more than sufficient for this workload and follows RFC 1918 private address space conventions.

### Decision: Four subnets across two Availability Zones

| Subnet | CIDR | AZ | Tier |
|---|---|---|---|
| public-subnet-a | 10.0.1.0/24 | us-east-1a | Public |
| public-subnet-b | 10.0.2.0/24 | us-east-1b | Public |
| private-subnet-a | 10.0.10.0/24 | us-east-1a | Private |
| private-subnet-b | 10.0.11.0/24 | us-east-1b | Private |

**Why two AZs?** To enable high availability. If one AZ fails entirely (which has happened in AWS history), the application continues serving from the other AZ. RDS Multi-AZ and the ALB both require at least two AZs to function.

**Why /24 subnets?** Each subnet provides 256 IPs (minus 5 reserved by AWS = 251 usable). This is more than enough for personal-project scale, and the round numbering convention makes diagrams readable.

### Decision: Public vs private subnet separation

- **Public subnets** host the Application Load Balancer (ALB), which must be internet-facing. They have a route to the Internet Gateway via the public route table.
- **Private subnets** host application servers (EC2) and the database (RDS). They have no direct route to the internet, which means even if a server is compromised, an attacker cannot easily exfiltrate data through the front door.

### Decision: Layered Security Groups

Security Groups reference each other rather than CIDR blocks:

```
Internet (0.0.0.0/0) → [sg-alb :80/443] → [sg-web :80] → [sg-db :5432]
```

This pattern provides two benefits over CIDR-based rules:

1. **Dynamic membership.** New instances added to `sg-web` automatically gain database access without rule edits.
2. **Tighter scope.** Only resources explicitly placed in `sg-web` can reach the database, regardless of their IP address within the VPC.

### Trade-offs documented

- **No NAT Gateway.** A NAT Gateway costs ~$32/month and is required for private resources to make outbound calls to the internet (e.g., `yum update`, API calls to AWS services). For Phase 2 we skip it to stay in Free Tier. In Phase 3, EC2 instances will use **VPC Endpoints** (free for S3 and DynamoDB) or **AWS Systems Manager** for management instead of NAT.
- **No IPv6.** Adds complexity without benefit at this stage. Could be added later if needed.

---

## Future phases

- **Phase 3 — Compute and Data:** EC2 in private subnets, RDS PostgreSQL, S3, ALB, IAM Roles.
- **Phase 4 — Observability and Resilience:** CloudWatch, SNS alarms, WAF, Shield Standard documentation.
- **Phase 5 — IaC and Polish:** Terraform conversion, lessons learned, screenshots, demo video.
