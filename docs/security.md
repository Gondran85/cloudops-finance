---

## Phase 2 — Network Security

### Network segmentation

- **VPC isolation.** The application runs in a dedicated VPC, not the default one. The default VPC has open Security Groups and public subnets in every AZ — unsafe for any real workload.
- **Tier separation.** Resources are placed in subnets according to their exposure:
  - Public-facing components (ALB) live in public subnets.
  - Application servers and databases live in private subnets, with no route to the internet.
- **No public IPs on application servers.** EC2 instances are launched without public IPs in the next phase. All inbound traffic must pass through the ALB.

### Layered Security Groups

A three-tier Security Group chain enforces least-privilege network access:

| SG | Inbound source | Inbound port | Purpose |
|---|---|---|---|
| `sg-alb` | `0.0.0.0/0` | 80, 443 | Accept HTTP/HTTPS from internet |
| `sg-web` | `sg-alb` | 80 | Accept traffic only from ALB |
| `sg-db` | `sg-web` | 5432 | Accept DB traffic only from web tier |

SG-to-SG references (rather than CIDR ranges) ensure that scope-of-access shrinks automatically as resources are added or removed from each tier.

### Trade-offs

- **SSH access in `sg-web`** is restricted to "My IP" as a fallback for debugging. In production, this would be removed entirely and replaced by AWS Systems Manager Session Manager (no inbound ports needed).
- **No NACL customization.** Default Network ACLs (allow all) are used because they apply at the subnet level and Security Groups already enforce strict rules. NACLs would be added in a production environment for an additional layer.
