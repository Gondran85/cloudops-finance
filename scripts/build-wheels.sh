#!/bin/bash
# ============================================================================
# CloudOps Finance — Build Python wheels for offline EC2 install
# ============================================================================
# The EC2 instances run in a private subnet with no NAT Gateway and therefore
# cannot reach PyPI. Dependencies are installed offline from pre-built wheels
# stored in S3 (the "deployment artifact" pattern). This script produces those
# wheels.
#
# WHY DOCKER:
#   Wheels must be built with the SAME Python version and platform as the
#   target instance (Amazon Linux 2023 -> Python 3.9, linux/amd64). Running
#   `pip download` on a different host Python silently drops conditional
#   dependencies whose environment markers (e.g. python_version < "3.10")
#   are evaluated against the host, not the target. Building inside a
#   python:3.9-slim container guarantees correct, deterministic resolution.
#   See docs/lessons-learned.md (Phase 3, learnings #3 and #4).
#
# USAGE:
#   ./build-wheels.sh
#   Run from the repository root. Requires Docker and the AWS CLI configured
#   for an identity allowed to write to the target bucket. CloudShell works
#   (Docker and AWS CLI are pre-installed).
#
# RESULT:
#   Wheels are written to ./wheels/ locally and uploaded to
#   s3://${S3_BUCKET}/app/wheels/. The EC2 bootstrap then installs them with
#   `pip install --no-index --find-links`.
# ============================================================================
 
set -euo pipefail
 
# ----------------------------------------------------------------------------
# Configuration
# ----------------------------------------------------------------------------
S3_BUCKET="cloudops-static-765936999166"
AWS_REGION="us-east-1"
PYTHON_VERSION="3.9"
PLATFORM="manylinux2014_x86_64"
REQUIREMENTS="src/requirements.txt"
WHEELS_DIR="wheels"
 
# ----------------------------------------------------------------------------
# Preconditions
# ----------------------------------------------------------------------------
if [ ! -f "$REQUIREMENTS" ]; then
  echo "ERROR: $REQUIREMENTS not found. Run this script from the repo root."
  exit 1
fi
 
if ! command -v docker >/dev/null 2>&1; then
  echo "ERROR: docker is not available."
  exit 1
fi
 
if ! command -v aws >/dev/null 2>&1; then
  echo "ERROR: aws CLI is not available."
  exit 1
fi
 
# ----------------------------------------------------------------------------
# 1. Build wheels inside a Python 3.9 container matching the EC2 runtime
# ----------------------------------------------------------------------------
echo "Cleaning local wheels directory..."
rm -rf "$WHEELS_DIR"
mkdir -p "$WHEELS_DIR"
 
echo "Downloading wheels inside python:${PYTHON_VERSION}-slim (linux/amd64)..."
docker run --rm \
  -v "$PWD/src:/src:ro" \
  -v "$PWD/$WHEELS_DIR:/wheels" \
  --platform linux/amd64 \
  "python:${PYTHON_VERSION}-slim" \
  pip download \
    -r "/src/requirements.txt" \
    -d /wheels \
    --only-binary=:all: \
    --platform "$PLATFORM" \
    --implementation cp \
    --abi "cp${PYTHON_VERSION/./}"
 
WHEEL_COUNT=$(find "$WHEELS_DIR" -name '*.whl' | wc -l)
echo "Built ${WHEEL_COUNT} wheels."
 
if [ "$WHEEL_COUNT" -lt 1 ]; then
  echo "ERROR: no wheels were produced. Check $REQUIREMENTS."
  exit 1
fi
 
# ----------------------------------------------------------------------------
# 2. Sync wheels to S3 (replace the prefix so removed deps don't linger)
# ----------------------------------------------------------------------------
echo "Clearing existing wheels in S3..."
aws s3 rm "s3://${S3_BUCKET}/app/wheels/" --recursive --region "$AWS_REGION"
 
echo "Uploading ${WHEEL_COUNT} wheels to S3..."
aws s3 cp "$WHEELS_DIR/" "s3://${S3_BUCKET}/app/wheels/" \
  --recursive --region "$AWS_REGION"
 
echo "Verifying upload..."
aws s3 ls "s3://${S3_BUCKET}/app/wheels/" --summarize --region "$AWS_REGION" | tail -2
 
echo "Done. EC2 instances launched from the Launch Template will now install"
echo "these wheels offline during bootstrap."
