# Reusable LocalStack AWS provider settings
# Usage in a lab:
#   module "ls" { source = "../../modules/localstack-provider" }
#   # or copy providers.tf pattern from labs

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

variable "endpoint" {
  type    = string
  default = "http://localhost:4566"
}

variable "region" {
  type    = string
  default = "us-east-1"
}

provider "aws" {
  region                      = var.region
  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  s3_use_path_style           = true

  endpoints {
    apigateway     = var.endpoint
    cloudformation = var.endpoint
    cloudwatch     = var.endpoint
    dynamodb       = var.endpoint
    ec2            = var.endpoint
    es             = var.endpoint
    elasticache    = var.endpoint
    firehose       = var.endpoint
    iam            = var.endpoint
    kinesis        = var.endpoint
    lambda         = var.endpoint
    rds            = var.endpoint
    redshift       = var.endpoint
    route53        = var.endpoint
    s3             = var.endpoint
    secretsmanager = var.endpoint
    ses            = var.endpoint
    sns            = var.endpoint
    sqs            = var.endpoint
    ssm            = var.endpoint
    stepfunctions  = var.endpoint
    sts            = var.endpoint
  }
}
