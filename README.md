# GPU Onboarding Gate
<img src="https://github.com/user-attachments/assets/53f0322b-fc00-4958-8299-6a66193ea158"
Local-first infrastructure work on AWS primitives, run against LocalStack so
nothing costs money until you want it to. Everything here is written as
Terraform, tested with real end-to-end scripts, and torn down cleanly.

## What's in here

The headline is the GPU onboarding gate. The rest are the building blocks that
led up to it.

| Lab | What it is |
|---|---|
| `labs/04-gpu-gate` | The control plane for my GPU validation fleet. Lambda + API Gateway + DynamoDB that decides PROVISION, HOLD, or RMA for each node. |
| `labs/03-lambda-hello` | A minimal Lambda, the starting point. |
| `labs/02-dynamodb-crud` | DynamoDB read/write as code. |
| `labs/01-s3-static` | S3 provisioning with Terraform. |

The full GPU validation story spans two repos. The node side (health checks,
burn tests, network checks, Ansible) lives in the `gpu-validation` repo. This
repo is the gate that receives those reports and makes the onboarding call.

## Quick start

```bash
cloud up      # start LocalStack (Docker)
cloud doctor  # check it's healthy
```

Then pick a lab and apply it:

```bash
cd labs/04-gpu-gate
terraform init && terraform apply -auto-approve
./verify.sh   # end-to-end test
```

LocalStack runs at `http://localhost:4566` with dummy credentials, so none of
this touches a real AWS account.

## The GPU onboarding gate

The headline piece. A GPU node posts its raw validation report to a
`POST /validate` endpoint. A Lambda applies the gate policy and appends an
audit record to DynamoDB.

- any `FAIL` means `RMA` (pull the node)
- any `WARN` means `HOLD` (manual review)
- otherwise `PROVISION` (onboard it)

The node reports. The gate decides. A node never gates itself.

See `labs/04-gpu-gate/` for the code and a full walkthrough.

## Setup

- Docker (for LocalStack)
- AWS CLI v2
- Terraform

The `cloud` launcher is a small TUI/CLI wrapper around the common commands
(the name refers to the local tool, not this repo).
