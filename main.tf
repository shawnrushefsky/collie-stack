locals {
  api_artifact_path  = "${path.module}/collie-api.zip"
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

resource "aws_lambda_function" "collie" {
  filename      = local.api_artifact_path
  function_name = var.stack_name
  role          = aws_iam_role.collie_role.arn
  handler       = "index.handler"

  runtime = "nodejs12.x"

  source_code_hash = filebase64sha256(local.api_artifact_path)

  environment {
    variables = {
      INDEX_S3_BUCKET = aws_s3_bucket.index.bucket
      STACK_NAME = var.stack_name
    }
  }
}

resource "aws_apigatewayv2_api" "api" {
  name          = var.stack_name
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "collie" { 
  api_id = aws_apigatewayv2_api.api.id
  integration_type = "AWS_PROXY"
  integration_method = "POST"
  integration_uri = aws_lambda_function.collie.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "root" {
  api_id = aws_apigatewayv2_api.api.id
  route_key = "ANY /"
  target = "integrations/${aws_apigatewayv2_integration.collie.id}"
}

resource "aws_apigatewayv2_route" "all" {
  api_id = aws_apigatewayv2_api.api.id
  route_key = "ANY /{proxy+}"
  target = "integrations/${aws_apigatewayv2_integration.collie.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id = aws_apigatewayv2_api.api.id
  name = "$default"
  auto_deploy = true
}

resource "aws_lambda_permission" "allow_api_gateway" {
  statement_id = "AllowExecutionFromAPIGateway"
  action = "lambda:InvokeFunction"
  function_name = aws_lambda_function.collie.function_name
  principal = "apigateway.amazonaws.com"
  source_arn = "${aws_apigatewayv2_api.api.execution_arn}/*/*/*"
}