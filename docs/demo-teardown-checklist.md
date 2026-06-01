# CloudOps Finance — Demo Teardown Checklist

> **Purpose:** Run this at the END of every demo session to avoid surprise charges.
> Keep it visible while you work. Region: **us-east-1**.

---

## The one rule

There are two kinds of resources in this project:

- **DELETE** — they bill for as long as they *exist*. There is no "stopped" state.
- **STOP** — they bill only while *running*. Stopping them costs ~$0.

If you only remember one thing: **the ALB and the Interface VPC Endpoints must be DELETED, not stopped.**

---

## Teardown — run in this order

### 1. DELETE — Application Load Balancer
- EC2 → Load Balancers → select `cloudops-alb` → Actions → **Delete**
- Why: ~$16/month, **no Free Tier**, no "stop" option. This is the single most expensive item.

### 2. DELETE — Target Group (optional but tidy)
- EC2 → Target Groups → select `cloudops-tg-web` → Actions → **Delete**
- Why: harmless to keep (it is free), but deleting keeps the account clean.

### 3. DELETE — the 3 Interface VPC Endpoints (SSM)
- VPC → Endpoints → select the three: `ssm`, `ssmmessages`, `ec2messages` → Actions → **Delete**
- Why: ~$0.01/h each per AZ (~$0.06/h total). Small, but it adds up if forgotten.
- **Keep** the S3 **Gateway** endpoint — it is free.

### 4. STOP — the 2 EC2 instances
- EC2 → Instances → select both → Instance state → **Stop instance** (NOT terminate)
- Why: stopped t2.micro costs ~$0 (only a few cents of EBS storage). You can restart later in seconds.

### 5. STOP — the RDS instance
- RDS → Databases → `cloudops-finance-db` → Actions → **Stop temporarily**
- Why: stopped RDS costs ~$0. Note: AWS auto-starts it after 7 days — just stop it again if that happens.

---

## What you DO NOT touch (free or near-free, leave running)

| Resource | Why it stays |
|---|---|
| S3 buckets | Free Tier (a few KB) |
| S3 Gateway VPC Endpoint | Free, always |
| Secrets Manager | ~$0.40/month (already running since Phase 3A) |
| VPC, subnets, route tables, IGW, Security Groups | All free |
| IAM Role, CloudTrail, Budgets | All free / negligible |

---

## Verification — confirm you really zeroed the billable items

Open **CloudShell** and run:

```bash
# Any load balancers still alive? (should be empty)
aws elbv2 describe-load-balancers --region us-east-1 --query "LoadBalancers[].LoadBalancerName" --output text

# Any interface endpoints still alive? (should show only the S3 gateway, or nothing)
aws ec2 describe-vpc-endpoints --region us-east-1 --query "VpcEndpoints[].{Service:ServiceName,Type:VpcEndpointType,State:State}" --output table

# EC2 instances and their state (should be 'stopped')
aws ec2 describe-instances --region us-east-1 --query "Reservations[].Instances[].{Id:InstanceId,State:State.Name}" --output table

# RDS state (should be 'stopped')
aws rds describe-db-instances --region us-east-1 --query "DBInstances[].{Id:DBInstanceIdentifier,State:DBInstanceStatus}" --output table
```

**Pass criteria:** no load balancers listed; no interface endpoints (only S3 gateway, if any); EC2 = stopped; RDS = stopped.

---

## Safety net (already in place from Phase 1)

- **Budgets** at $1 / $5 / $10 will email you if anything bills unexpectedly.
- Worst realistic case of a forgotten ALB over a weekend: ~$1–2 — not a disaster, and you will be warned at $1.
- Check **Cost Explorer** ~24h after the session to confirm the charge landed where expected (cents).

---

## To run the demo again later

You do not rebuild from scratch:
1. Start the 2 EC2 instances (EC2 → Start instance)
2. Start the RDS (RDS → Actions → Start)
3. Recreate the 3 Interface VPC Endpoints (~2 min) and the ALB + Target Group (~10 min)
4. Done — app is live again.
