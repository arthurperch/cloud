# Lab 04 — GPU Production Onboarding Gate

Control plane for a GPU validation fleet, built on AWS primitives
(Lambda + API Gateway + DynamoDB) and run locally on LocalStack.

## Architecture

```
[GPU node]  gpu_validate.py ──JSON report──▶ API Gateway POST /validate
   (NVML checks)                                   │
                                                   ▼
                                           Lambda "gpu-gate"
                                             • parse report
                                             • DECIDE the gate
                                             • append audit record
                                                   │
                                                   ▼
                                            DynamoDB "gpu-nodes"
                                            (node_id, report_ts) history
```

**Design principle:** the node *reports* raw checks; the control plane
*decides* the gate. A node cannot gate itself. This mirrors real fleet
onboarding (and RMA) where approval lives in a central service, not on the box.

## Gate policy

| Report status | Decision | Meaning |
|---------------|----------|---------|
| any FAIL      | `RMA`    | return material authorization — pull the node |
| any WARN      | `HOLD`   | pending manual review / bandwidth burn test |
| else          | `PROVISION` | onboard into production |

## Files

- `handler.py` — Lambda: parse + decide + write DynamoDB
- `main.tf` — DynamoDB table, IAM role/policy, Lambda, API Gateway (REST v1)
- `verify.sh` — 4 scenarios (PROVISION / RMA / HOLD / 400) + item count

## Run

```bash
cloud up                                   # start LocalStack
set -a; source ~/lab/cloud/env/localstack.env; set +a
cd ~/lab/cloud/labs/04-gpu-gate
terraform init && terraform apply -auto-approve
./verify.sh                                # end-to-end gate test
```

## Submit a real report from the GPU node

```bash
cd ~/lab/gpu-validation
.venv/bin/python validator/gpu_validate.py --json reports/live.json
.venv/bin/python validator/submit_report.py \
    --report reports/live.json \
    --endpoint "http://localhost:4566/restapis/<api_id>/prod/_user_request_/validate"
```

## Notes / gotchas

- LocalStack free tier does **not** include `apigatewayv2` (HTTP API) — use the
  classic **REST API v1** resources (`aws_api_gateway_rest_api`, `_resource`,
  `_method`, `_integration`, `_deployment`).
- The `*.execute-api.*` domain in `terraform output` does not resolve locally;
  invoke via `http://localhost:4566/restapis/{id}/{stage}/_user_request_/{path}`.
- Re-running `terraform apply` with a new stage name forces a fresh deployment;
  otherwise API Gateway changes may not take effect.
