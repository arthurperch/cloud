#!/usr/bin/env bash
# Count records in the gate's DynamoDB audit trail. Self-contained: sets its
# own dummy credentials + region so it works from any directory.
set -euo pipefail
AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_DEFAULT_REGION=us-east-1 \
  aws --endpoint-url=http://localhost:4566 dynamodb scan \
    --table-name gpu-nodes --select COUNT --query Count --output text
