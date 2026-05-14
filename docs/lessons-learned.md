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

## Phase 2 — Networking (To be filled)

*Pending completion.*
