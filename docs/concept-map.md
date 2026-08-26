# AWS <-> Azure concept map

Fill your own one-liners after each dual-cloud lab.

| Concept | AWS | Azure | Notes |
|---|---|---|---|
| Compute VM | EC2 | Virtual Machine | |
| Object storage | S3 | Blob Storage | |
| Identity | IAM | Entra ID + RBAC | |
| Serverless fn | Lambda | Azure Functions | |
| NoSQL | DynamoDB | Cosmos DB (table API) | |
| Queue | SQS | Queue Storage / Service Bus | |
| Pub/sub | SNS | Event Grid / Service Bus topics | |
| K8s managed | EKS | AKS | |
| IaC primary | CloudFormation / Terraform | ARM / Bicep / Terraform | We use Terraform both sides |
| Local emu | LocalStack | Azurite (blobs/queues/tables) | Phase later |

## Request path (LocalStack)

```
aws/terraform CLI  -->  http://localhost:4566  -->  LocalStack container  -->  service emulator
```
