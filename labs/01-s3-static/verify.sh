#!/usr/bin/env bash
set -euo pipefail
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1
EP="${AWS_ENDPOINT_URL:-http://localhost:4566}"
BUCKET="cloud-lab-a1-static"
echo "list buckets:"
aws --endpoint-url="$EP" s3 ls
echo "list objects in $BUCKET:"
aws --endpoint-url="$EP" s3 ls "s3://$BUCKET/"
aws --endpoint-url="$EP" s3 cp "s3://$BUCKET/hello.txt" - | grep -q "hello from localstack"
echo "PASS lab 01-s3-static"
