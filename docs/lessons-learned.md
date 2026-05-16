# Lessons Learned

This document captures key learnings throughout the CloudOps Finance 
project, organized by phase.

---

## Phase 1 — Foundation (Date: 2026-05-14)

### What was accomplished
- AWS account hardened: MFA enabled on root user, no access keys on root
- IAM user `cloudops-admin` created with MFA and the AWS CLI configured
- Cost governance: three budgets ($1, $5, $10) plus a forecasted budget ($20)
- Multi-region CloudTrail enabled with log file validation
- Dedicated S3 bucket for CloudTrail logs, hardened with a bucket policy 
  that denies object deletion without MFA
- Cost Explorer activated and Cost Anomaly Detection monitor configured
- GitHub repository initialized with a professional structure (managed 
  through the web UI to support workflows across multiple machines)

### Key learnings

1. **Foundation before features.** The temptation to "create an EC2 first" 
   is real, but it costs you later in security incidents and unexpected 
   bills. Spending two to three days on governance pays off across the 
   entire project lifecycle.

2. **The root user is a sealed vault.** Once MFA is enabled and access 
   keys are removed, root should only be used for billing changes or 
   account recovery. Daily work flows through IAM users.

3. **Multi-region CloudTrail is non-negotiable.** Even when operating in 
   a single region, attackers can pivot to other regions. Multi-region 
   coverage is free and closes that gap.

4. **Layered cost defense works.** Budgets provide threshold alerts, 
   Anomaly Detection adds ML-driven behavioral alerts, and Cost Explorer 
   provides visualization for investigation. None of them is sufficient 
   on its own.

5. **Documenting while building beats documenting at the end.** The 
   README, lessons learned, and decisions written down as I worked were 
   five times easier to produce than reconstructing them later.

6. **Questioning incomplete guidance is a strength, not rudeness.** 
   Professional environments value people who hold the bar high — 
   including for their mentors and senior engineers.

### Mistakes I avoided
- Using the root user for daily operations (would dilute audit trails)
- Storing access keys in code or `.env` files committed to git
- Creating S3 buckets without encryption or with public access enabled
- Configuring CloudTrail in a single region only

### Decisions and trade-offs
- Used **SSE-S3** instead of **SSE-KMS** for CloudTrail log encryption 
  to stay in Free Tier (~$1/month savings). In a regulated production 
  environment, SSE-KMS would be preferred for granular key control. 
  Documented in `security.md`.
- Used the **AdministratorAccess** managed policy on `cloudops-admin` 
  for project velocity. In a production environment, this would be 
  replaced with scoped, service-specific policies.
- Managed the GitHub repository **entirely through the web UI** instead 
  of local Git, because the workflow involves switching between machines 
  frequently. The web UI is the single source of truth.

### Time invested
- Phase 1 total: approximately 6–8 hours over three days.

### What I'll do next
- **Phase 2 — Networking:** VPC with public and private subnets across 
  two Availability Zones, Internet Gateway, route tables, and Security 
  Groups in layers (ALB → Web → DB).

---

## Phase 2 — Networking (Date: 16-05-2026)

### What was accomplished
- Created dedicated VPC `cloudops-vpc` with CIDR `10.0.0.0/16`
- Designed four-subnet layout across two AZs (us-east-1a and us-east-1b)
- Created and attached an Internet Gateway
- Configured public route table (with route to IGW) and private route table (local only)
- Implemented three-tier Security Groups using SG-to-SG references
- Applied consistent tagging across all resources

### Key learnings

1. **CIDR planning is permanent.** VPC CIDR cannot be changed after creation 
   (only extended). Choosing `10.0.0.0/16` upfront gave plenty of room to grow 
   without overlap with on-prem networks (typically 192.168.x.x).

2. **Subnets belong to AZs, route tables belong to VPCs.** Each subnet is 
   pinned to one Availability Zone. Route tables are VPC-wide and applied 
   to subnets through associations.

3. **The "public" or "private" of a subnet is determined by its route table.** 
   A subnet only becomes public when its associated route table has a route 
   to an Internet Gateway. The subnet name is just a label for humans.

4. **SG-to-SG references > CIDR references.** Referencing another Security 
   Group as the source makes the rule dynamic and tied to identity rather 
   than IP address. New instances joining the source SG automatically inherit 
   access.

5. **Tags pay off later.** Tagging consistently across VPC components means 
   that Tag Editor and Cost Allocation Tags can show resource counts and 
   costs grouped by project, environment, and tier without rework.

### Mistakes I avoided
- Using the default VPC (insecure defaults)
- Placing all subnets in a single AZ (no resilience)
- Allowing `0.0.0.0/0` to access the database SG
- Forgetting to associate the public route table with public subnets 
  (subnets would default to the private route table and lose internet access)

### Decisions and trade-offs
- **Skipped NAT Gateway** to stay in Free Tier (~$32/month savings). 
  Private resources will use VPC Endpoints or Systems Manager for outbound 
  needs in Phase 3.
- **Skipped IPv6** to reduce complexity. Can be added later if needed.
- **Default NACLs** kept as allow-all because Security Groups already 
  enforce strict access. In a production environment, NACLs would add 
  another defense layer.

### Time invested
- Phase 2 total: approximately 8 hours over three days.

### What I'll do next
- **Phase 3 — Compute and Data:** Launch EC2 instances in private subnets, 
  provision RDS PostgreSQL Multi-AZ, create S3 buckets, set up the ALB, 
  configure IAM Roles, and deploy the Flask application.
