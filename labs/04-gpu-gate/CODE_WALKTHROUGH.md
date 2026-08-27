# How the gate works

A plain walkthrough of the gate. This is the serverless half of the GPU
validation project. The node side lives in a separate repo, the gpu-validation
repo. This repo is only the control plane.

## The flow

A GPU node finishes its checks and posts a JSON report to the gate. The gate
does three things: parse the report, decide what to do, and write the decision
to DynamoDB. Then it sends the decision back to the node.

```
GPU node -> POST /validate -> Lambda handler -> decide() -> DynamoDB
                                                  |
                                                  v
                                         PROVISION / HOLD / RMA
```

## handler.py

This is the whole brain. It's small, about eighty lines, and every line is
there for a reason.

### The table reference

At the top, three lines set up the DynamoDB connection:

```python
TABLE = os.environ.get("NODES_TABLE", "gpu-nodes")
dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(TABLE)
```

`TABLE` reads an environment variable for the table name, with a default of
`gpu-nodes` if the variable isn't set. The Terraform config sets that variable
to the actual table name, which is how the Lambda knows which table to write
to without any hardcoded name inside the code.

### decide()

This is the gate policy in code. It takes a list of checks and returns a
decision.

```python
if "FAIL" in statuses:
    return "RMA", reasons
if "WARN" in statuses:
    return "HOLD", reasons
return "PROVISION", reasons
```

The order matters. FAIL is checked before WARN, so a single FAIL beats any
number of WARNs. A node with nine passing checks and one failure is an RMA.
That's the conservative behavior you want for production hardware.

The function also collects `reasons`, a list of which checks failed or warned,
so the response can say not just "HOLD" but "HOLD because pcie_link was WARN".

### handler()

This is the entry point. API Gateway calls this function with an `event`
dictionary containing the HTTP request.

The first thing it does is unpack the body. API Gateway passes the body as a
JSON string, so it has to be parsed before the code can read fields off it:

```python
body = event.get("body") or "{}"
if isinstance(body, str):
    body = json.loads(body)
```

Then it validates the input. If there's no `node_id` and no `checks` list, it
returns a 400 with an error message. That's the malformed-request case, and
the `verify.sh` script tests it explicitly.

Then it decides, writes the record, and returns the decision. The audit record
includes the node id, timestamp, decision, reasons, the number of checks, and
the source string, so every field needed to reconstruct "what happened to this
node and why" is in the table.

## main.tf

The Terraform that provisions everything. It builds four resources:

- **DynamoDB table** (`gpu-nodes`) with `node_id` as the partition key and
  `report_ts` as the sort key. That two-key layout means you can look up all
  the reports for one node in time order, which is the natural query for an
  audit trail.
- **IAM role and policy** that lets the Lambda write to that one table and
  nothing else. Least privilege: the function can't touch any other resource.
- **Lambda function** running the handler, with the table name passed in
  through an environment variable.
- **API Gateway REST API** with a single `POST /validate` route wired to the
  Lambda, plus a Lambda permission that lets API Gateway invoke it.

The provider block at the top points at LocalStack instead of real AWS:

```hcl
provider "aws" {
  region = "us-east-1"
  endpoints {
    lambda     = "http://localhost:4566"
    dynamodb   = "http://localhost:4566"
    apigateway = "http://localhost:4566"
    ...
  }
}
```

Those `endpoints` entries are what redirect every AWS call to your local
LocalStack container instead of the real cloud. That's the entire trick that
makes this testable for free.

One detail worth knowing: the `archive_file` data source zips `handler.py` at
apply time, so the Lambda always deploys with the current version of the code.
You edit the handler, run `terraform apply`, and the new code ships.

## verify.sh

Four curl requests that prove the gate works end to end.

1. A report with all PASS checks should return PROVISION.
2. A report with a FAIL should return RMA.
3. A report with a WARN should return HOLD.
4. A request with no `node_id` should return a 400.

Each scenario is a real HTTP call through API Gateway to the Lambda and back,
not a unit test. It also prints the DynamoDB item count at the end, so you can
see the audit records actually landed.

## What connects this to the node repo

The `submit_report.py` script in the gpu-validation repo posts to the endpoint
this repo creates. The two halves are decoupled: the node only needs the URL,
and it doesn't know or care whether the gate is Lambda or a shell script. The
gate only needs the JSON shape, and it doesn't care which validator produced
it. That decoupling is the point of a control plane.
