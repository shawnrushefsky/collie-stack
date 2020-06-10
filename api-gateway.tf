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