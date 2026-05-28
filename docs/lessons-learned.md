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

  ## Phase 3 — Compute, Data, and Deployment (Date: 27–28/05/2026)

### What was accomplished
- Created IAM Role `cloudops-ec2-role` (SSM, S3 read-only, Secrets Manager)
- Provisioned two S3 buckets (static assets, uploads), private, versioned, SSE-S3
- Created DB Subnet Group spanning both private subnets
- Provisioned RDS PostgreSQL (`db.t3.micro`, private subnet, no public access)
- Stored database credentials in AWS Secrets Manager (`cloudops/db/credentials`)
- Created four VPC Endpoints: three Interface (SSM, SSMMessages, EC2Messages),
  one Gateway (S3); later added a fourth Interface endpoint (Secrets Manager)
- Built a Launch Template with IMDSv2 required, no key pair, SSM-only access
- Deployed a Flask application behind Nginx + gunicorn as a systemd service
- Launched two EC2 instances across two AZs, fronted by an Application Load
  Balancer with health checks, both targets healthy
- Achieved fully zero-touch instance provisioning (launch to serving traffic
  in under one minute, no manual intervention)

### Key learnings

1. **Private subnets reach AWS services through VPC Endpoints, but never the
   public internet.** `dnf` worked (Amazon Linux repositories live in AWS S3,
   reachable via the S3 Gateway Endpoint), but `pip install` failed because
   PyPI is on the public internet, unreachable without a NAT Gateway. The
   distinction between "AWS service" and "public internet" is the entire
   reason the dependency strategy had to change.

2. **The deployment artifact pattern replaces internet access.** Instead of
   adding a NAT Gateway (recurring cost) or exposing the instances (security
   risk), Python dependencies were pre-packaged as wheels in S3 and installed
   offline with `pip install --no-index --find-links`. This is the standard
   approach in regulated, network-isolated environments where build and
   runtime are separated by design.

3. **Cross-platform `pip download` silently drops conditional dependencies.**
   Wheels downloaded in CloudShell (Python 3.11+) installed fine for most
   packages but failed on the EC2 target (Python 3.9) with missing
   `importlib-metadata` and later `greenlet`. Even with `--platform`,
   `--python-version 3.9`, `--implementation cp`, and `--abi cp39`, pip
   evaluated environment markers such as `python_version < "3.10"` against the
   host interpreter, not the target. The fix was to run `pip download` inside
   a `python:3.9-slim` Docker container matching the target runtime exactly:
   22 wheels resolved correctly versus 19. The lesson generalizes: build
   environments must match runtime environments, which is the core argument
   for hermetic, containerized builds. Flag-based cross-compilation is
   best-effort; a matching interpreter is deterministic.

4. **A second latent bug hid behind the first.** The container build also
   pulled `urllib3 1.26.20` (constrained by botocore on Python 3.9) instead
   of the `2.6.3` that CloudShell had selected. The wrong version would have
   broken HTTPS calls to AWS at runtime, but the earlier `importlib-metadata`
   error masked it. Resolving dependency issues at the correct layer surfaces
   problems that ad-hoc patching leaves buried.

5. **In-place file edits in bootstrap scripts are fragile; overwrite instead.**
   A `sed` command intended to delete the default Nginx `server` block removed
   an unbalanced brace on Amazon Linux 2023, producing
   `"location" directive is not allowed here` and a failed Nginx start. The
   robust fix was to overwrite `nginx.conf` entirely with a known-good version
   (no default server block, `include conf.d/*.conf`) and write the app's
   server block as a separate file. Declarative replacement beats imperative
   editing for machine-generated config.

6. **Secrets Manager needs its own VPC Endpoint in a private subnet.** The app
   booted fine (imports only) and `/health` responded (static JSON), but `/`
   hung for ~30 seconds then returned 500. The root cause: every request
   called `get_secret_value`, which opened a TCP socket to the public
   Secrets Manager endpoint with no route back, timing out until gunicorn
   killed the worker. Adding a Secrets Manager Interface Endpoint with Private
   DNS enabled dropped the call from a 30 s timeout to 177 ms. A fast 500 and
   a slow 500 are different problems: response time is a diagnostic signal.

7. **Stale DNS can mask a working endpoint.** Immediately after the endpoint
   became available, a hostname connection still failed while a direct
   connection to the endpoint's private IP succeeded. The local resolver had
   cached the old public IP. Forcing a fresh lookup resolved it. When DNS and
   direct-IP behavior disagree, suspect caching before configuration.

8. **Health checks should test liveness, not full functionality.** The ALB
   health check targets `/health` (static, no DB) rather than `/` (queries
   the database). If it targeted `/`, a database problem would mark every
   instance unhealthy and take the whole service down, when the processes
   themselves are alive. Health checks answer "is the process up?", not "is
   everything perfect?".

9. **Reproducible builds require pinning transitive dependencies.** Only the
   five direct packages are pinned in `requirements.txt`; transitive versions
   (e.g. `urllib3`) are resolved at download time and can drift between runs.
   A `pip freeze > requirements-lock.txt` step would make builds fully
   deterministic. Direct pins alone are insufficient.

10. **Database seeding does not belong in instance bootstrap.** The sample-data
    `INSERT` in `db-init.sql` is not idempotent. Two instances running the
    same bootstrap would duplicate the seed data. Schema creation
    (`CREATE TABLE IF NOT EXISTS`) is safe to repeat; data seeding is a
    separate one-time migration step. The schema was initialized once,
    manually, against the RDS instance.

11. **Declared state is not real state — always verify.** On two occasions,
    instances believed to be stopped were in fact still running, and a planned
    teardown left compute and database online. Checking the actual state with
    the AWS CLI caught both. This is the human-process version of the same
    principle behind `terraform plan`: never trust intent, inspect the system.

12. **Launch Template versions provide free rollback.** Each fix (pip offline,
    Nginx overwrite) became a new immutable template version (v1 → v2 → v3),
    with the default pointing at the latest known-good version. Reverting a
    bad deploy is a one-click change of the default version, with no rebuild.

13. **IMDSv2 and SSM-only access minimize attack surface.** Instances run with
    IMDSv2 required (mitigating SSRF-based credential theft), no SSH key pair,
    and no inbound port 22. All administrative access goes through Session
    Manager, authenticated by IAM and fully audited in CloudTrail. There is no
    public entry point to the instances at all.

### Mistakes I avoided
- Adding a NAT Gateway out of convenience (would have cost ~$32/month and
  undermined the private-subnet security narrative)
- Exposing instances with public IPs or an SSH bastion to work around the
  PyPI problem
- Patching each missing wheel one at a time instead of fixing the build
  environment at the root
- Running `db-init.sql` from the bootstrap, which would have duplicated seed
  data across two instances
- Terminating the only working instance before proving the new bootstrap
  worked on a second instance first

### Decisions and trade-offs
- **No NAT Gateway; offline wheels via S3 instead.** Zero recurring cost,
  stronger isolation. Trade-off: dependency changes require rebuilding and
  re-uploading wheels rather than a live `pip install`.
- **RDS single-AZ for the demo**, documented as "Multi-AZ-ready" — enabling
  Multi-AZ is a one-click toggle with no application change. Saves cost during
  development while keeping the architecture honest about production posture.
- **Secrets Manager Interface Endpoint** chosen over caching credentials in
  the app or adding NAT. Consistent with the existing VPC Endpoint pattern,
  keeps the security story intact. Trade-off: ~$0.01/h while running.
- **HTTP-only ALB listener** for the demo. HTTPS via ACM + Route 53 is
  deferred to a later phase. The browser shows "Not secure" — a conscious,
  documented limitation, not an oversight.
- **Endpoint policies left as full access** for the demo. Production would
  scope them to specific actions and resource ARNs (e.g. `GetSecretValue` on
  the single secret).

### Time invested
- Phase 3 total: approximately 12–14 hours, including substantial debugging
  of the offline dependency and networking issues.

### What I'll do next
- **Phase 4 — Observability and Edge:** CloudWatch dashboards and alarms,
  SNS notifications, and edge protection (WAF, Shield). Re-create the ALB for
  the live portions.
- **Phase 5 — Infrastructure as Code and polish:** Terraform to codify the
  console-built resources, a `build-wheels.sh` script for reproducible wheel
  builds, cost estimate and Well-Architected review documents, and a LinkedIn
  post.
