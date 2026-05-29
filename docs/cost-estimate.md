# Cost Estimate

This document breaks down the cost of running CloudOps Finance and explains
the cost-control strategy. The project is built to stay within (or very close
to) the AWS Free Tier, with the two billable components created only during
active sessions.

> All figures are approximate, for **us-east-1**, and current as of the build.
> Always confirm against the AWS Pricing pages and your own Cost Explorer.

---

## The two kinds of cost in this project

1. **Always-safe (Free Tier or free):** EC2 `t3.micro`, RDS `db.t3.micro`, S3,
   the S3 Gateway VPC Endpoint, Secrets Manager (cents), CloudTrail management
   events, CloudWatch alarms/dashboard within Free Tier, AWS Budgets, SNS email.
2. **Bills per hour while it exists:** the Application Load Balancer and the
   Interface VPC Endpoints. These are the only components that need active cost
   management — created for a session, removed afterward.

---

## Per-service breakdown

| Service | Free Tier | Cost beyond Free Tier (approx.) | Notes |
|---------|-----------|----------------------------------|-------|
| EC2 `t3.micro` × 2 | 750 h/month (12 months) | ~$0 within Free Tier | 750 h is shared across all `t2/t3.micro` in the account |
| RDS `db.t3.micro` | 750 h/month (12 months) | ~$0 within Free Tier | Single-AZ; Multi-AZ would roughly double it |
| S3 (code + wheels + uploads) | 5 GB (12 months) | a few cents | ~21 MB of wheels + small assets |
| S3 Gateway VPC Endpoint | Always free | $0 | Used for code/wheels/dnf |
| Interface VPC Endpoints × 4 | None | ~$0.01/h each (~$0.04/h total) | SSM ×3 + Secrets Manager; delete when idle |
| Application Load Balancer | None | ~$0.0225/h (~$16/month if 24/7) | Plus small LCU charge; the priciest item |
| Secrets Manager | None | ~$0.40/month per secret | One secret |
| CloudWatch alarms | 10 alarms free | $0 | Using 7 |
| CloudWatch dashboard | 3 dashboards free | $0 | Using 1 |
| CloudWatch basic metrics | 5-minute metrics free | $0 | Detailed 1-minute metrics avoided (would bill) |
| SNS email | 1,000 notifications/month free | $0 | A handful of alerts |
| CloudTrail (management events) | Free | $0 | Multi-region |
| AWS Budgets | First 2 budgets free | $0 | Within free allotment |
| Shield Standard | Always free | $0 | Automatic on the ALB |

---

## Two operating modes

### Mode A — everything running 24/7 (worst case)
If the ALB and all four Interface Endpoints were left on for a full month, on
top of Free-Tier compute:

| Component | Monthly |
|-----------|---------|
| ALB | ~$16 |
| Interface VPC Endpoints × 4 | ~$29 (~$0.04/h × 720 h) |
| Secrets Manager | ~$0.40 |
| **Total** | **~$45/month** |

This is the number to *avoid*. It is what happens if you forget teardown.

### Mode B — billable resources only during sessions (actual practice)
The ALB and Interface Endpoints are created for a demo/work session (a few
hours) and deleted afterward. EC2 and RDS are stopped between sessions.

| Component | Per session (~3 h) |
|-----------|--------------------|
| ALB | ~$0.07 |
| Interface VPC Endpoints × 4 | ~$0.12 |
| Everything else | ~$0 (Free Tier) |
| **Total per session** | **well under $1** |

A handful of sessions per month keeps the project under **~$1–2 total**.

---

## A real lesson: forecast is not actual cost

During the build, an AWS Budget alert fired:

> *Forecasted cost exceeds $3.00 — forecasted amount $3.62.*

The instinct was to assume $3.62 had already been spent and to tear everything
down in a hurry. Checking the actual month-to-date cost by service told a
different story — the real spend was a **fraction of a cent**, with several
line items showing small credits.

**Why the gap?** A budget *forecast* extrapolates aggressively from sparse data
and short usage spikes early in the month. A few hours of ALB and endpoint
usage on one day were projected linearly across the whole month, inflating the
forecast to $3.62. The forecast is an **early-warning signal**, not a statement
of spend.

**The correct response** — and what was ultimately done — is to inspect actual
cost-by-service in Cost Explorer before reacting:

```bash
aws ce get-cost-and-usage --region us-east-1 \
  --time-period "Start=$(date -u +%Y-%m-01),End=$(date -u +%Y-%m-%d)" \
  --granularity MONTHLY --metrics UnblendedCost \
  --group-by Type=DIMENSION,Key=SERVICE \
  --output table
```

Reacting to a forecast without verifying real cost leads to unnecessary
teardowns. Distinguishing *forecast* from *actual* is a basic but real FinOps
skill.

---

## Cost-control practices in place

- **AWS Budgets** at $1, $5, $10 plus a forecast alert — layered thresholds.
- **Cost Anomaly Detection** for behavioural (ML-based) alerts.
- **A teardown checklist** (`demo-teardown-checklist.md`) that distinguishes
  resources to *delete* (ALB, Interface Endpoints) from resources to *stop*
  (EC2, RDS), with a CLI verification block — because "I stopped it" must be
  verified, not assumed.
- **Stopping vs deleting** understood per resource: the ALB has no "stopped"
  state and must be deleted; EC2/RDS bill ~$0 while stopped.

---

## Cost of the planned (not-yet-built) components

When the roadmap items are added, their cost profile:

| Planned service | Cost profile |
|-----------------|--------------|
| Lambda | Free Tier permanent (1M requests/month) — effectively $0 |
| CloudFront | Free Tier permanent (1 TB + 10M requests/month) — effectively $0 |
| Route 53 | ~$0.50/month per hosted zone + a registered domain (~$12–15/year) |
| WAF | ~$5/month per Web ACL + ~$1/rule + $0.60/M requests — the costly one |
| ACM certificate | Free (with CloudFront/ALB) |
| RDS Multi-AZ | Roughly doubles the RDS cost vs single-AZ |

Strategy when adding these: **Lambda and CloudFront can stay on** (free at this
scale); **WAF and Route 53 are created for a demo and removed**, same as the ALB.
