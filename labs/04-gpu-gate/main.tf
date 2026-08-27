# Lab 04, GPU production onboarding gate (Lambda + DynamoDB + API Gateway)
#
# Control plane for the GPU validation fleet. A GPU node POSTs its raw
# validation report to /validate; the Lambda applies the gate policy
# (PASS->PROVISION, WARN->HOLD, FAIL->RMA) and appends an audit record to
# DynamoDB. The node reports, the control plane decides.

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region                      = "us-east-1"
  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  endpoints {
    lambda     = "http://localhost:4566"
    iam        = "http://localhost:4566"
    sts        = "http://localhost:4566"
    logs       = "http://localhost:4566"
    dynamodb   = "http://localhost:4566"
    apigateway = "http://localhost:4566"
  }
}

# --- DynamoDB: append-only audit table --------------------------------
resource "aws_dynamodb_table" "gpu_nodes" {
  name         = "gpu-nodes"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "node_id"
  range_key    = "report_ts"

  attribute {
    name = "node_id"
    type = "S"
  }
  attribute {
    name = "report_ts"
    type = "S"
  }
}

# --- Lambda code ------------------------------------------------------
data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "${path.module}/gate.zip"
  source {
    content  = file("${path.module}/handler.py")
    filename = "handler.py"
  }
}

# --- IAM --------------------------------------------------------------
resource "aws_iam_role" "gate" {
  name = "cloud-lab-04-gate-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_policy" "gate" {
  name = "cloud-lab-04-gate-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action   = ["dynamodb:PutItem", "dynamodb:GetItem", "dynamodb:Query"]
      Effect   = "Allow"
      Resource = aws_dynamodb_table.gpu_nodes.arn
    }]
  })
}

resource "aws_iam_role_policy_attachment" "gate" {
  role       = aws_iam_role.gate.name
  policy_arn = aws_iam_policy.gate.arn
}

# --- Lambda function --------------------------------------------------
resource "aws_lambda_function" "gate" {
  function_name    = "cloud-lab-04-gpu-gate"
  role             = aws_iam_role.gate.arn
  handler          = "handler.handler"
  runtime          = "python3.12"
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      NODES_TABLE = aws_dynamodb_table.gpu_nodes.name
    }
  }
}

# --- API Gateway (REST API v1, free LocalStack tier) ------------------
resource "aws_api_gateway_rest_api" "gate" {
  name        = "cloud-lab-04-gpu-gate-api"
  description = "GPU validation onboarding gate"
}

resource "aws_api_gateway_resource" "validate" {
  rest_api_id = aws_api_gateway_rest_api.gate.id
  parent_id   = aws_api_gateway_rest_api.gate.root_resource_id
  path_part   = "validate"
}

resource "aws_api_gateway_method" "validate" {
  rest_api_id   = aws_api_gateway_rest_api.gate.id
  resource_id   = aws_api_gateway_resource.validate.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "validate" {
  rest_api_id             = aws_api_gateway_rest_api.gate.id
  resource_id             = aws_api_gateway_resource.validate.id
  http_method             = aws_api_gateway_method.validate.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.gate.invoke_arn
}

resource "aws_api_gateway_deployment" "gate" {
  depends_on  = [aws_api_gateway_integration.validate]
  rest_api_id = aws_api_gateway_rest_api.gate.id
  stage_name  = "prod"
}

resource "aws_lambda_permission" "gate" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.gate.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.gate.execution_arn}/*/*"
}

output "api_endpoint" {
  value = "${aws_api_gateway_deployment.gate.invoke_url}/validate"
}
