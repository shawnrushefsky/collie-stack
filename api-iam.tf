resource "aws_iam_role" "collie_api_role" {
  name = "${var.stack_name}-api-role"

  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    sid = "LambdaAssumeRole"

    actions = ["sts:AssumeRole"]

    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "api_access_s3" {
  statement {
    sid = "ListBuckets"

    effect = "Allow"

    actions = ["s3:ListAllMyBuckets"]

    resources = [
      "arn:aws:s3:::*"
    ]
  }

  statement {
    sid = "AccessIndexBucket"

    effect = "Allow"

    actions = [
      "s3:*"
    ]

    resources = [
      "${aws_s3_bucket.index.arn}/",
      "${aws_s3_bucket.index.arn}/*"
    ]
  }
}

data "aws_iam_policy_document" "api_use_sqs" {
  statement {
    sid = "SQSAccess"

    effect = "Allow"

    actions = [
      "sqs:SendMessage"
    ]

    resources = [
      aws_sqs_queue.indexing_queue.arn
    ]
  }
}

data "aws_iam_policy_document" "api_cloudwatch" {
  statement {
    sid = "CreateLogGroup"

    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
    ]

    resources = [
      "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"
    ]
  }

  statement {
    sid = "SendLogs"

    effect = "Allow"

    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]

    resources = [
      "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${aws_lambda_function.collie_api.function_name}:*"
    ]
  }
}

resource "aws_iam_policy" "api_access_s3" {
  name        = "${var.stack_name}-api-access-s3"
  description = "This policy grants access to the collie index bucket"

  policy = data.aws_iam_policy_document.api_access_s3.json
}

resource "aws_iam_role_policy_attachment" "api_access_s3" {
  role       = aws_iam_role.collie_api_role.name
  policy_arn = aws_iam_policy.api_access_s3.arn
}

resource "aws_iam_policy" "api_use_sqs" {
  name        = "${var.stack_name}-api-use-sqs"
  description = "This policy grants access to the collie index bucket"

  policy = data.aws_iam_policy_document.api_use_sqs.json
}

resource "aws_iam_role_policy_attachment" "api_use_sqs" {
  role       = aws_iam_role.collie_api_role.name
  policy_arn = aws_iam_policy.api_use_sqs.arn
}

resource "aws_iam_policy" "api_cloudwatch" { 
  name = "${var.stack_name}-api-cloudwatch-logs"
  description = "This policy grants lambda the ability to write logs to cloudwatch"

  policy = data.aws_iam_policy_document.api_cloudwatch.json
}

resource "aws_iam_role_policy_attachment" "api_cloudwatch" {
  role = aws_iam_role.collie_api_role.name
  policy_arn = aws_iam_policy.api_cloudwatch.arn
}