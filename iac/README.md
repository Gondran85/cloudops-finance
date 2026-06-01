# Infrastructure as Code (IaC)

This folder holds the declarative, version-controlled definitions for parts of
the CloudOps Finance infrastructure.

## Implemented

### CloudWatch dashboard (dashboard-as-code)

- **`cloudwatch-dashboard.json`** — the full dashboard definition: 8 metric
  widgets (EC2 CPU/network/status-check, RDS CPU/connections/storage/memory)
  plus an alarm-status panel, laid out on CloudWatch's 24-column grid. Metric
  math converts raw bytes to GB/MB for readability.
- **`create-dashboard.sh`** — an idempotent wrapper around
  `aws cloudwatch put-dashboard`. Running it creates the dashboard, or updates
  the existing one in place — so the live dashboard always matches the JSON.

```bash
# from the repo root or from iac/
./iac/create-dashboard.sh
```

This is the "dashboard belongs in code, not in clicks" principle: the dashboard
is reproducible, reviewable in a pull request, and replicable in another account
— unlike one built by hand in the console.

## Planned (not yet built)

- **Terraform modules** to codify the network, compute, data, and observability
  resources currently provisioned via the Console + scripts. Deferred until the
  tool is studied properly — a half-correct Terraform state is worse than none.
  See the roadmap in the main `README.md`.
