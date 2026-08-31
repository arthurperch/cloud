# GPU Onboarding Gate

<table>
  <tr>
    <td valign="top">
      <img src="https://github.com/user-attachments/assets/26104483-d07c-4425-855c-ddf1e9f6f13f" alt="ascii-art-1787951291179" style="width: 512px; height: 410px;" />
    </td>
    <td valign="top" style="padding-left: 20px; line-height: 1.6;">
      <h3><b>The control plane of GPU onboarding</b></h3>
      <p><b>Lambda</b> - applies the gate policy</p>
      <p><b>API Gateway</b> - POST /validate</p>
      <p><b>DynamoDB</b> - append-only audit trail</p>
      <p><b>Terraform + LocalStack</b> - run it locally, no AWS bill</p>
      <p><b>The node reports. The gate decides.</b></p>
    </td>
  </tr>
</table>

Local AWS practice on LocalStack, so nothing costs money until you want it to. Written as Terraform, tested with real scripts, torn down cleanly.

## What's in here
The headline is the GPU onboarding gate. The rest are the building blocks that led up to it.

| Lab | What it is |
|---|---|
| `labs/04-gpu-gate` | The control plane for my GPU validation fleet. Lambda + API Gateway + DynamoDB that decides PROVISION, HOLD, or RMA for each node. |
| `labs/03-lambda-hello` | A minimal Lambda, the starting point. |
| `labs/02-dynamodb-crud` | DynamoDB read/write as code. |
| `labs/01-s3-static` | S3 provisioning with Terraform. |

The full GPU validation story spans two repos, one pipeline:

- **Node side** — health checks, burn tests, network checks, Ansible — lives in
  **[gpu-validation](https://github.com/arthurperch/gpu-validation)**.
- **Control plane** — this repo — receives those reports and makes the
  onboarding call.

Start with the node side if you want the whole picture; come back here for the
decision logic and audit trail.

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
