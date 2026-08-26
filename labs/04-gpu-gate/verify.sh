#!/usr/bin/env bash
set -euo pipefail
export AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_DEFAULT_REGION=us-east-1
EP="http://localhost:4566"
# LocalStack serves REST APIs at /restapis/{id}/{stage}/_user_request/{path}
# (the *.execute-api.* domain from terraform output doesn't resolve locally)
API_ID="$(aws --endpoint-url="$EP" apigateway get-rest-apis --query 'items[0].id' --output text)"
API="$EP/restapis/$API_ID/prod/_user_request_/validate"
echo "API: $API"

# Scenario 1: healthy node -> PROVISION
resp=$(curl -s -X POST "$API" -H 'Content-Type: application/json' -d '{
  "node_id": "GPU-test-pass-001",
  "source": "gpu_validate/1.0",
  "checks": [
    {"name":"driver_version","value":"610.57.04","status":"PASS","detail":"CUDA 13.3"},
    {"name":"temperature_c","value":47,"status":"PASS","detail":"limit 85C"},
    {"name":"pcie_link","value":"Gen3 x16","status":"PASS","detail":"max Gen3 x16"},
    {"name":"ecc","value":"N/A","status":"N/A","detail":"consumer"}
  ]
}')
echo "$resp" | grep -q '"PROVISION"' && echo "  PASS scenario-1 -> PROVISION" || { echo "  FAIL scenario-1"; echo "$resp"; exit 1; }

# Scenario 2: failing node -> RMA
resp=$(curl -s -X POST "$API" -H 'Content-Type: application/json' -d '{
  "node_id": "GPU-test-fail-002",
  "source": "gpu_validate/1.0",
  "checks": [
    {"name":"driver_version","value":"610.57.04","status":"PASS","detail":"CUDA 13.3"},
    {"name":"temperature_c","value":96,"status":"FAIL","detail":"limit 85C"},
    {"name":"pcie_link","value":"Gen1 x16","status":"FAIL","detail":"under load"}
  ]
}')
echo "$resp" | grep -q '"RMA"' && echo "  PASS scenario-2 -> RMA" || { echo "  FAIL scenario-2"; echo "$resp"; exit 1; }

# Scenario 3: warn -> HOLD
resp=$(curl -s -X POST "$API" -H 'Content-Type: application/json' -d '{
  "node_id": "GPU-test-warn-003",
  "source": "gpu_validate/1.0",
  "checks": [
    {"name":"driver_version","value":"610.57.04","status":"PASS","detail":"CUDA 13.3"},
    {"name":"pcie_link","value":"Gen1 x16","status":"WARN","detail":"downshifted"}
  ]
}')
echo "$resp" | grep -q '"HOLD"' && echo "  PASS scenario-3 -> HOLD" || { echo "  FAIL scenario-3"; echo "$resp"; exit 1; }

# Scenario 4: malformed -> 400
code=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$API" -H 'Content-Type: application/json' -d '{"checks": []}')
[ "$code" = "400" ] && echo "  PASS scenario-4 -> 400 on missing node_id" || { echo "  FAIL scenario-4 got $code"; exit 1; }

# Verify audit records landed in DynamoDB
echo -n "  DynamoDB item count: "
aws --endpoint-url="$EP" dynamodb scan --table-name gpu-nodes --select COUNT --query Count --output text

echo "PASS lab 04-gpu-gate"
