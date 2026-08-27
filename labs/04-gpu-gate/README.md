# GPU Onboarding Gate

The control plane for the GPU validation fleet. A GPU node posts its raw
validation report here, and this service decides what to do with that node:
provision it, hold it, or send it back.

The node reports. The gate decides. A node never gates itself.

## What it is

Three AWS services wired together with Terraform, run locally on LocalStack:

- **API Gateway** exposes a `POST /validate` endpoint. The GPU node posts its
  JSON report here.
- **Lambda** (`handler.py`) reads the report, applies the gate policy, and
  writes an audit record.
- **DynamoDB** (`gpu-nodes`) stores every decision, keyed by node id and
  timestamp, so the whole history of a node is traceable.

## The gate policy

| Report status | Decision | Meaning |
|---|---|---|
| any `FAIL` | `RMA` | return material authorization: pull the node |
| any `WARN` | `HOLD` | pending manual review or a bandwidth burn test |
| otherwise | `PROVISION` | onboard into production |

The policy is conservative on purpose. A single `FAIL` anywhere means the node
comes out of the fleet. A `WARN` is not a failure, but it's not a green light
either, so the node waits for a human or a more thorough test.

## Why the gate lives in a separate repo

The validators run on the GPU node itself. The gate runs in the cloud (or
LocalStack for local dev). They deploy to different places, so they live in
different repos. The node side can be shipped to a hundred machines while the
gate side ships once.

## Files

- `handler.py` - the Lambda. Parse report, decide, write DynamoDB.
- `main.tf` - Terraform for the DynamoDB table, IAM role and policy, the Lambda
  function, and the API Gateway REST API.
- `verify.sh` - four end to end scenarios (PROVISION, RMA, HOLD, and a 400 for
  malformed input) plus an item count from DynamoDB.

## Run it

```bash
cloud up                                          # start LocalStack
set -a; source ~/lab/cloud/env/localstack.env; set +a
cd ~/lab/cloud/labs/04-gpu-gate
terraform init && terraform apply -auto-approve
./verify.sh                                       # end to end gate test
```

## Submit a real report from the GPU node

```bash
cd ~/lab/gpu-validation
.venv/bin/python validator/gpu_validate.py --json reports/live.json
.venv/bin/python validator/submit_report.py \
    --report reports/live.json \
    --endpoint "http://localhost:4566/restapis/<api_id>/prod/_user_request_/validate"
```

## Gotchas

- LocalStack free tier does not include `apigatewayv2` (the HTTP API). Use the
  classic REST API v1 resources instead: `aws_api_gateway_rest_api`,
  `_resource`, `_method`, `_integration`, `_deployment`.
- The `*.execute-api.*` domain in `terraform output` does not resolve locally.
  Invoke through `http://localhost:4566/restapis/{id}/{stage}/_user_request_/{path}`.
- API Gateway changes need a fresh deployment to take effect. Re-running
  `terraform apply` with a new `stage_name` forces one.
