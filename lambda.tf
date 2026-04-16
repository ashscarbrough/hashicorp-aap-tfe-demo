# Zip the Lambda function code
data "archive_file" "packer_webhook" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/packer_webhook"
  output_path = "${path.module}/lambda/packer_webhook.zip"
}

# IAM role for Lambda
resource "aws_iam_role" "packer_webhook_lambda" {
  name = "hcp-packer-webhook-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "lambda.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "packer_webhook_lambda_logs" {
  role       = aws_iam_role.packer_webhook_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Lambda function
resource "aws_lambda_function" "packer_webhook" {
  function_name    = "hcp-packer-webhook"
  filename         = data.archive_file.packer_webhook.output_path
  source_code_hash = data.archive_file.packer_webhook.output_base64sha256
  role             = aws_iam_role.packer_webhook_lambda.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  timeout          = 30

  environment {
    variables = {
      TFE_WORKSPACE_ID = var.tfe_workspace_id
      TFE_TOKEN        = var.tfe_trigger_token
    }
  }
}

# Lambda function URL — public HTTPS endpoint, no auth needed
# since HCP Packer doesn't support IAM auth on webhooks
resource "aws_lambda_function_url" "packer_webhook" {
  function_name      = aws_lambda_function.packer_webhook.function_name
  authorization_type = "NONE"
}