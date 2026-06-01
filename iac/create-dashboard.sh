#!/bin/bash
# ============================================================================
# CloudOps Finance — Create or update the CloudWatch dashboard
# ============================================================================
# Idempotent: `put-dashboard` creates the dashboard if it does not exist, or
# replaces the existing one with the same name. Re-running this script keeps
# the dashboard in sync with the JSON definition.
#
# Run from the repository root or from the iac/ directory.
# ============================================================================

set -euo pipefail

DASHBOARD_NAME="CloudOpsFinance"
AWS_REGION="us-east-1"

# Locate the JSON next to this script, regardless of where the user runs it from
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DASHBOARD_JSON="${SCRIPT_DIR}/cloudwatch-dashboard.json"

if [ ! -f "$DASHBOARD_JSON" ]; then
  echo "ERROR: dashboard definition not found at $DASHBOARD_JSON"
  exit 1
fi

if ! command -v aws >/dev/null 2>&1; then
  echo "ERROR: aws CLI is not available."
  exit 1
fi

echo "Applying dashboard '$DASHBOARD_NAME' from $DASHBOARD_JSON ..."
aws cloudwatch put-dashboard \
  --region "$AWS_REGION" \
  --dashboard-name "$DASHBOARD_NAME" \
  --dashboard-body "file://$DASHBOARD_JSON" \
  --output table

echo ""
echo "Dashboard URL:"
echo "https://${AWS_REGION}.console.aws.amazon.com/cloudwatch/home?region=${AWS_REGION}#dashboards:name=${DASHBOARD_NAME}"
