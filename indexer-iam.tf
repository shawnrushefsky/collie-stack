resource "aws_iam_role" "collie_indexer_role" {
  name = "${var.stack_name}-indexer-role"

  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

data "aws_iam_policy_document" "indexer_access_s3" {
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

data "aws_iam_policy_document" "indexer_use_sqs" {
  statement {
    sid = "SQSAccess"

    effect = "Allow"

    actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes"
    ]

    resources = [
      aws_sqs_queue.indexing_queue.arn
    ]
  }
}

data "aws_iam_policy_document" "indexer_cloudwatch" {
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
      "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${aws_lambda_function.collie_indexer.function_name}:*"
    ]
  }
}

resource "aws_iam_policy" "indexer_access_s3" {
  name        = "${var.stack_name}-indexer-access-s3"
  description = "This policy grants access to the collie index bucket"

  policy = data.aws_iam_policy_document.indexer_access_s3.json
}

resource "aws_iam_role_policy_attachment" "indexer_access_s3" {
  role       = aws_iam_role.collie_indexer_role.name
  policy_arn = aws_iam_policy.indexer_access_s3.arn
}

resource "aws_iam_policy" "indexer_use_sqs" {
  name        = "${var.stack_name}-indexer-use-sqs"
  description = "This policy grants access to the collie index bucket"

  policy = data.aws_iam_policy_document.indexer_use_sqs.json
}

resource "aws_iam_role_policy_attachment" "indexer_use_sqs" {
  role       = aws_iam_role.collie_indexer_role.name
  policy_arn = aws_iam_policy.indexer_use_sqs.arn
}

resource "aws_iam_policy" "indexer_cloudwatch" { 
  name = "${var.stack_name}-indexer-cloudwatch-logs"
  description = "This policy grants lambda the ability to write logs to cloudwatch"

  policy = data.aws_iam_policy_document.indexer_cloudwatch.json
}

resource "aws_iam_role_policy_attachment" "indexer_cloudwatch" {
  role = aws_iam_role.collie_indexer_role.name
  policy_arn = aws_iam_policy.indexer_cloudwatch.arn
}