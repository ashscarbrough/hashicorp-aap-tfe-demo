# ------------------------------------------------------------------------------
# Lambda function for ASG lifecycle hook
# ------------------------------------------------------------------------------
# Zip the Lambda function code
data "archive_file" "liberty_app_asg_lifecycle_hook" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/asg_lifecycle_webhook"
  output_path = "${path.module}/lambda/liberty_app_asg_lifecycle_webhook.zip"
}

# Lambda function
resource "aws_lambda_function" "liberty_app_asg_lifecycle_webhook" {
  function_name    = "liberty-app-asg-lifecycle-webhook"
  filename         = data.archive_file.liberty_app_asg_lifecycle_webhook.output_path
  source_code_hash = data.archive_file.liberty_app_asg_lifecycle_webhook.output_base64sha256
  role             = aws_iam_role.liberty_app_asg_lifecycle_webhook_lambda.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  timeout          = 60

  environment {
    variables = {
      AAP_HOST               = var.aap_hostname
      AAP_TOKEN              = var.aap_token
      AAP_JOB_TEMPLATE_ID    = var.aap_configuration_job_template_id
    }
  }
}

# IAM role for Lambda
resource "aws_iam_role" "liberty_app_asg_lifecycle_webhook_lambda" {
  name = "liberty-app-asg-lifecycle-webhook-lambda-role"

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

resource "aws_iam_role_policy_attachment" "liberty_app_asg_lifecycle_webhook_lambda_logs" {
  role       = aws_iam_role.liberty_app_asg_lifecycle_webhook_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
