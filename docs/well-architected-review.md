# Well-Architected Framework Review

A self-assessment of CloudOps Finance against the six pillars of the
**AWS Well-Architected Framework**. This is an honest review: each pillar lists
what is **implemented**, the **gaps**, and the **conscious trade-offs**. A
portfolio project at Free-Tier scale will not score perfectly on every pillar,
and pretending otherwise would be less credible than naming the gaps.

> Scope note: this project is built and operated manually (Console + scripts)
> at near-zero cost. Several "production-grade" controls are deliberately
> deferred and marked as such.

---

## 1. Operational Excellence

*Run and monitor systems; continuously improve processes and procedures.*

**Implemented**
- Infrastructure decisions and rationale documented per phase
  (`architecture.md`), with lessons captured after each phase
  (`lessons-learned.md`).
- **Zero-touch provisioning:** instances configure themselves from a versioned
  Launch Template + bootstrap script, launch to serving traffic in under a
  minute, no manual steps.
- **Versioned, repeatable artifacts:** bootstrap script, wheel build script,
  dashboard-as-code (JSON + idempotent apply), all in Git.
- **Observability:** CloudWatch dashboard + alarms, SNS notifications, the
  notification path tested end-to-end.
- **Operational runbooks:** a teardown checklist with CLI verification.

**Gaps / planned**
- No CI/CD pipeline yet (GitHub Actions planned). Deployments are manual.
- No automated rollback beyond Launch Template version switching.
- No structured log aggregation/queries (CloudWatch Logs Insights) yet.

**Assessment:** Strong for the project's scale. Documentation and repeatability
are the standout strengths; automation of the deploy pipeline is the main gap.

---

## 2. Security

*Protect data, systems, and assets.*

**Implemented**
- Least-privilege intent: dedicated instance IAM role; MFA on all human access;
  root sealed.
- **No public attack surface on compute:** private subnets, no public IPs, no
  SSH, no port 22 — access only via SSM Session Manager, audited in CloudTrail.
- **IMDSv2 required** (mitigates SSRF credential theft).
- Layered, identity-based Security Groups (SG-to-SG).
- Secrets in Secrets Manager, fetched over a private VPC Endpoint; nothing
  sensitive in code or the repo.
- Encryption at rest (S3, RDS); multi-region CloudTrail with log validation.
- Offline dependency install removes a supply-chain pathway.

**Gaps / planned**
- **No HTTPS/TLS yet** — the ALB listener is HTTP only (ACM/CloudFront planned).
  This is the most significant security gap currently.
- **No WAF** (planned).
- IAM uses broad **managed policies** rather than scoped inline policies.
- RDS password set manually rather than RDS-managed rotation.

**Assessment:** Strong network and access posture; the clear gap is
encryption-in-transit at the edge (HTTPS), which is the top priority on the
roadmap. Full detail in `security.md`.

---

## 3. Reliability

*Ensure a workload performs its intended function correctly and consistently.*

**Implemented**
- **Multi-AZ compute:** two instances across two Availability Zones behind an
  ALB; loss of one AZ does not take the app down.
- **Health checks** on `/health` (liveness, decoupled from the database) with
  automatic removal of unhealthy targets.
- **Self-healing instances:** systemd restarts the app on failure; Launch
  Template allows quick replacement.

**Gaps / planned**
- **RDS is single-AZ** — a database AZ failure is currently a single point of
  failure. The design is Multi-AZ-ready (one-click promotion), deferred for
  cost.
- **No Auto Scaling Group** — instance count is fixed at two; a failed instance
  is replaced manually, not automatically (planned).
- **No automated RDS backups/restore tested** beyond defaults.

**Assessment:** Good at the compute tier (genuine multi-AZ HA); the data tier
is the honest weak point (single-AZ), explicitly a cost trade-off rather than
an oversight.

---

## 4. Performance Efficiency

*Use computing resources efficiently.*

**Implemented**
- **Right-sized** for the workload: `t3.micro` compute and `db.t3.micro`
  database match a low-traffic MVP; no over-provisioning.
- **Nginx reverse proxy** in front of gunicorn handles connection buffering and
  static-file serving efficiently.
- **VPC Endpoints** keep AWS-service traffic on the private network (lower
  latency, no internet round-trip) — e.g. Secrets Manager dropped from a 30 s
  timeout to ~177 ms once the endpoint existed.

**Gaps / planned**
- **No CDN/caching** at the edge (CloudFront planned) — all requests hit the
  origin.
- **No load testing** has been run; performance characteristics under traffic
  are unmeasured (the dashboard shows near-idle baselines).
- No autoscaling to match capacity to demand.

**Assessment:** Appropriately sized and efficient for current scale, but
performance under real load is unproven — load testing is the obvious next step.

---

## 5. Cost Optimization

*Avoid unnecessary costs.*

**Implemented**
- **Free-Tier-first** design; the only billable components (ALB, Interface
  Endpoints) are created per session and removed.
- **No NAT Gateway** (~$32/month avoided) — replaced by VPC Endpoints and the
  offline-wheels pattern.
- **Layered budgets** ($1/$5/$10 + forecast) and Cost Anomaly Detection.
- A **teardown checklist** with verification, and the documented discipline of
  distinguishing *delete* vs *stop* per resource.
- A real FinOps lesson documented: distinguishing **forecast from actual cost**
  after a budget alert (see `cost-estimate.md`).

**Gaps / planned**
- Cost-allocation tags exist but are not yet used to drive per-tier cost
  reporting.
- No Savings Plans / Reserved Instances (correct — at this scale and with Free
  Tier, on-demand is right).

**Assessment:** The strongest pillar. Cost is actively managed and the
trade-offs are explicit throughout.

---

## 6. Sustainability

*Minimize the environmental impact of running cloud workloads.*

**Implemented**
- **Right-sizing** avoids idle over-provisioned capacity.
- **Resources powered down when idle** (EC2/RDS stopped between sessions, ALB
  and endpoints deleted) — directly reduces energy consumption, not just cost.
- **us-east-1** is one of AWS's largest regions with significant renewable
  investment (region choice was driven by Free Tier and latency, with this as
  a secondary benefit).

**Gaps / planned**
- Serverless (Lambda) for event-driven work would reduce idle compute further
  (planned).
- No measurement of carbon impact (AWS Customer Carbon Footprint Tool not yet
  reviewed).

**Assessment:** The power-down discipline aligns cost and sustainability
naturally; deeper sustainability work (serverless-first, carbon measurement) is
future scope.

---

## Summary

| Pillar | Strength | Main gap |
|--------|----------|----------|
| Operational Excellence | Documentation, zero-touch, dashboard-as-code | No CI/CD |
| Security | Private/SSM-only access, IMDSv2, secrets isolation | No HTTPS/TLS yet |
| Reliability | Multi-AZ compute + health checks | RDS single-AZ |
| Performance Efficiency | Right-sized, private endpoints | No CDN, no load testing |
| Cost Optimization | Free-Tier-first, active governance | (minor) tag-driven reporting |
| Sustainability | Power-down discipline | No carbon measurement |

**Overall:** The architecture demonstrates solid Well-Architected thinking at
Free-Tier scale, with the trade-offs made explicit rather than hidden. The
highest-value next steps are HTTPS/TLS (Security), RDS Multi-AZ (Reliability),
and a CI/CD pipeline (Operational Excellence).
