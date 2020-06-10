locals {
  api_artifact_path     = "${path.module}/collie-api.zip"
  indexer_artifact_path = "${path.module}/collie-indexer.zip"
  dynamo_partition_key  = "id"
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "aws_s3_bucket" "index" {
  bucket_prefix = "${var.stack_name}-index"
  acl           = "private"

  versioning {
    enabled = false
  }
}

resource "aws_s3_bucket_public_access_block" "private_index" {
  bucket = aws_s3_bucket.index.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
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
      INDEX_S3_BUCKET          = aws_s3_bucket.index.bucket
      QUEUE_URL                = aws_sqs_queue.indexing_queue.id
      LOCK_TABLE               = aws_dynamodb_table.distributed_lock.id
      LOCK_TABLE_PARTITION_KEY = local.dynamo_partition_key
    }
  }
}

resource "aws_lambda_function" "collie_indexer" {
  filename      = local.indexer_artifact_path
  function_name = "${var.stack_name}-indexer"
  role          = aws_iam_role.collie_indexer_role.arn
  handler       = "index.handler"

  runtime = "nodejs12.x"

  source_code_hash = filebase64sha256(local.indexer_artifact_path)

  environment {
    variables = {
      INDEX_S3_BUCKET          = aws_s3_bucket.index.bucket
      LOCK_TABLE               = aws_dynamodb_table.distributed_lock.id
      LOCK_TABLE_PARTITION_KEY = local.dynamo_partition_key
    }
  }
}


resource "aws_sqs_queue" "indexing_queue" {
  name                        = "${var.stack_name}-collie-ingest.fifo"
  fifo_queue                  = true
  visibility_timeout_seconds  = 300
  content_based_deduplication = true
}

resource "aws_lambda_event_source_mapping" "event_source_mapping" {
  batch_size       = 10
  event_source_arn = aws_sqs_queue.indexing_queue.arn
  enabled          = true
  function_name    = aws_lambda_function.collie_indexer.arn
}

resource "aws_dynamodb_table" "distributed_lock" {
  name         = "${var.stack_name}-distributed-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = local.dynamo_partition_key

  attribute {
    name = local.dynamo_partition_key
    type = "S"
  }
}