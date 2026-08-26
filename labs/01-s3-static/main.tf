# Lab A1 — S3 static bucket on LocalStack
#
# Objective: create a bucket, upload an object, list it via AWS CLI endpoint.
# Pass: ./verify.sh exits 0
# Cleanup: terraform destroy -auto-approve

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
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
  s3_use_path_style           = true
  endpoints {
    s3  = "http://localhost:4566"
    sts = "http://localhost:4566"
    iam = "http://localhost:4566"
  }
}

resource "aws_s3_bucket" "lab" {
  bucket = "cloud-lab-a1-static"
}

resource "aws_s3_object" "hello" {
  bucket  = aws_s3_bucket.lab.id
  key     = "hello.txt"
  content = "hello from localstack lab a1\n"
}

output "bucket" {
  value = aws_s3_bucket.lab.id
}

output "object_key" {
  value = aws_s3_object.hello.key
}
