# Screenshots

Visual evidence of the implemented architecture, organized by phase and
numbered in chronological order. Every image is committed to this folder and
referenced by relative path, so the links never expire.

> Images must be **uploaded as files** to this folder (Add file → Upload
> files), not pasted into the editor. Pasted images use temporary signed URLs
> that expire within minutes and then render as broken images for everyone else.

---

## Phase 2 — Networking

### VPC creation
![VPC creation](02-vpc-creation.jpg)

### Four subnets (2 public + 2 private) across two AZs
![Subnets across two AZs](03-subnets-4-across-2az.jpg)

### Internet Gateway attached
![Internet Gateway attached](04-internet-gateway-attached.jpg)

### Route tables (public + private)
![Route tables](05-route-tables.jpg)

### Private subnet associations
![Private subnet associations](06-private-subnet-associations.jpg)

### Public subnet associations
![Public subnet associations](07-public-subnet-associations.jpg)

### Security Group — ALB tier (sg-alb)
![sg-alb](08-sg-alb.jpg)

### Security Group — Web tier (sg-web)
![sg-web](09-sg-web.jpg)

### Security Group — Database tier (sg-db)
![sg-db](10-sg-database.jpg)

---

## Phase 3 — Compute, Data & Deployment

*To be added: ALB with healthy targets, the app served through the ALB (public
URL visible), Launch Template versions, the zero-touch cloud-init log, and the
VPC Endpoints list.*

---

## Phase 4 — Observability

*To be added: the CloudWatch dashboard, the seven alarms in OK state, the SNS
topic, and the SNS subscription confirmation.*
