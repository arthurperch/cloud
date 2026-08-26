#!/usr/bin/env bash
set -euo pipefail
export AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_DEFAULT_REGION=us-east-1
EP="${AWS_ENDPOINT_URL:-http://localhost:4566}"
FN="cloud-lab-a3-hello"
out=$(aws --endpoint-url="$EP" lambda invoke --function-name "$FN" /tmp/a3-out.json)
cat /tmp/a3-out.json
grep -q "hello from lab a3" /tmp/a3-out.json
echo "PASS lab 03-lambda-hello"
