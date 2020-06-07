data "github_release" "collie_latest" {
  repository  = "collie"
  owner       = "shawnrushefsky"
  retrieve_by = "latest"
}

data "http" "collie_asset_info" {
  url = data.github_release.collie_latest.asserts_url
}

locals {
  asset_url = jsondecode(data.http.collie_asset_info.body)[0].browser_download_url
  zip_path  = "${path.module}/collie.zip"
}

resource "null_resource" "download_zip" {
  triggers = {
    exists = fileexists(local.zip_path)
    latest = local.asset_url
  }

  provisioner "local-exec" {
    command = "curl -L ${local.asset_url} --output ${local.zip_path}"
  }
}

resource "aws_s3_bucket" "index" {
  bucket_prefix = "${var.stack_name}-index"
  acl           = "private"

  versioning {
    enabled = false
  }
}

resource "aws_lambda_function" "collie" {
  depends_on = [null_resource.download_zip]
  filename      = local.zip_path
  function_name = var.stack_name
  role          = aws_iam_role.collie_role.arn
  handler       = "index.handler"

  runtime = "nodejs12.x"

  environment {
    variables = {
      INDEX_S3_BUCKET = aws_s3_bucket.index.bucket
    }
  }
}

resource "aws_apigatewayv2_api" "api" {
  name          = var.stack_name
  protocol_type = "HTTP"
  target        = aws_lambda_function.collie.arn
}

resource "aws_apigatewayv2_integration" "collie" { 
  api_id = aws_apigatewayv2_api.api.id
  integration_type = "AWS"
  integration_method = "ANY"
  integration_uri = aws_lambda_function.collie.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "root" {
  api_id = aws_apigatewayv2_api.api.id
  route_key = "ANY /"
  target = aws_apigatewayv2_integration.collie.id
}

resource "aws_apigatewayv2_route" "all" {
  api_id = aws_apigatewayv2_api.api.id
  route_key = "ANY /{proxy+}"
  target = aws_apigatewayv2_integration.collie.id
}