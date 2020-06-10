locals {
  api_artifact_path  = "${path.module}/collie-api.zip"
  indexer_artifact_path = "${path.module}/collie-indexer.zip"
}

resource "aws_s3_bucket" "index" {
  bucket_prefix = "${var.stack_name}-index"
  acl           = "private"

  versioning {
    enabled = false
  }
}

resource "aws_s3_bucket_public_access_block" "private_index" {
  bucket = aws_s3_bucket.index.id

  block_public_acls = true
  block_public_policy = true
  ignore_public_acls = true
  restrict_public_buckets = true
}

resource "aws_lambda_function" "collie_api" {
  filename      = local.api_artifact_path
  function_name = "${var.stack_name}-api"
  role          = aws_iam_role.collie_api_role.arn
  handler       = "index.handler"

  runtime = "nodejs12.x"

  source_code_hash = filebase64sha256(local.api_artifact_path)

  environment {
    variables = {
      INDEX_S3_BUCKET = aws_s3_bucket.index.bucket
      STACK_NAME = var.stack_name
      QUEUE_URL = aws_sqs_queue.terraform_queue.id
    }
  }
}

resource "aws_sqs_queue" "terraform_queue" { 
  name = "${var.stack_name}-collie-ingest.fifo"
  fifo_queue = true
  visibility_timeout_seconds = 300
}