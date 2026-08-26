#!/usr/bin/env bash
set -euo pipefail
export AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_DEFAULT_REGION=us-east-1
EP="${AWS_ENDPOINT_URL:-http://localhost:4566}"
TABLE="cloud-lab-a2-items"
aws --endpoint-url="$EP" dynamodb put-item \
  --table-name "$TABLE" \
  --item '{"id":{"S":"1"},"note":{"S":"lab-a2"}}'
aws --endpoint-url="$EP" dynamodb get-item \
  --table-name "$TABLE" \
  --key '{"id":{"S":"1"}}' | grep -q lab-a2
echo "PASS lab 02-dynamodb-crud"
