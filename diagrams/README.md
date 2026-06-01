# Architecture Diagrams

This folder holds the architecture diagram for CloudOps Finance. The diagram
below reflects the **implemented** architecture (not planned/roadmap
components). It is written in Mermaid, which GitHub renders natively, so it
stays versionable as text and never breaks as an image link.

> Planned components (Route 53, CloudFront, WAF, Lambda, HTTPS/ACM) are
> intentionally **not** shown here — see `docs/architecture.md` for the
> implemented-vs-planned breakdown.

---

## Implemented architecture (multi-AZ, 3-tier)

```mermaid
flowchart TB
    Internet([Internet / Users])

    subgraph VPC["VPC 10.0.0.0/16 — us-east-1"]
        direction TB

        subgraph Public["Public subnets (2 AZs)"]
            ALB["Application Load Balancer<br/>HTTP :80<br/>health check /health"]
        end

        subgraph PrivateApp["Private subnets — App tier (2 AZs)"]
            EC2A["EC2 web-a · t3.micro<br/>us-east-1a<br/>Nginx → gunicorn → Flask"]
            EC2B["EC2 web-b · t3.micro<br/>us-east-1b<br/>Nginx → gunicorn → Flask"]
        end

        subgraph PrivateData["Private subnets — Data tier (2 AZs)"]
            RDS["RDS PostgreSQL<br/>db.t3.micro · single-AZ<br/>(Multi-AZ-ready)"]
        end

        subgraph Endpoints["VPC Endpoints (no NAT Gateway)"]
            VPCE_S3["S3 Gateway Endpoint<br/>(free)"]
            VPCE_INT["Interface Endpoints<br/>SSM · SSMMessages · EC2Messages<br/>Secrets Manager"]
        end
    end

    subgraph AWSsvc["AWS services (private connectivity)"]
        S3["S3<br/>app code · wheels · uploads"]
        SM["Secrets Manager<br/>DB credentials"]
        SSM["Systems Manager<br/>Session Manager access"]
    end

    subgraph Observ["Observability & governance"]
        CW["CloudWatch<br/>7 alarms + dashboard"]
        SNS["SNS<br/>email alerts"]
        CT["CloudTrail<br/>multi-region audit"]
    end

    Internet -->|HTTP :80| ALB
    ALB -->|:80| EC2A
    ALB -->|:80| EC2B
    EC2A -->|:5432| RDS
    EC2B -->|:5432| RDS

    EC2A -.->|private| VPCE_S3
    EC2B -.->|private| VPCE_INT
    VPCE_S3 -.-> S3
    VPCE_INT -.-> SM
    VPCE_INT -.-> SSM

    EC2A -.->|metrics| CW
    RDS -.->|metrics| CW
    CW -->|alarm| SNS
```

---

## How to update this diagram

Edit the Mermaid block above directly in `README.md` — GitHub re-renders it on
save. No external tool, no image export. If a PNG/SVG export is needed later
(for a slide deck, for example), the Mermaid source can be exported from the
[Mermaid Live Editor](https://mermaid.live).

## Legend

- **Solid arrows** = request/data path (user → ALB → EC2 → RDS)
- **Dotted arrows** = private connectivity to AWS services via VPC Endpoints,
  and metric/alarm flow
- **No NAT Gateway** — private instances reach AWS services through VPC
  Endpoints only
