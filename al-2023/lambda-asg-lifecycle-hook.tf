# # ------------------------------------------------------------------------------
# # Lambda function for ASG lifecycle hook
# # ------------------------------------------------------------------------------
# # Zip the Lambda function code
# data "archive_file" "al2023_asg_lifecycle_hook" {
#   type        = "zip"
#   source_dir  = "${path.module}/lambda/al2023_asg_launch"
#   output_path = "${path.module}/lambda/al2023_asg_launch.zip"
# }

# # Lambda function
# resource "aws_lambda_function" "al2023_asg_lifecycle_hook" {
#   function_name    = "al2023-asg-lifecycle-hook"
#   filename         = data.archive_file.al2023_asg_lifecycle_hook.output_path
#   source_code_hash = data.archive_file.al2023_asg_lifecycle_hook.output_base64sha256
#   role             = aws_iam_role.al2023_asg_lifecycle_hook_lambda.arn
#   handler          = "handler.lambda_handler"
#   runtime          = "python3.12"
#   timeout          = 60

#   environment {
#     variables = {
#       AAP_HOST               = var.aap_hostname
#       AAP_TOKEN              = var.aap_token
#       AAP_JOB_TEMPLATE_ID    = var.asg_aap_job_template_id
#       AAP_INVENTORY_SOURCE_ID = var.asg_aap_inventory_id
#     }
#   }
# }

# # IAM role for Lambda
# resource "aws_iam_role" "al2023_asg_lifecycle_hook_lambda" {
#   name = "al2023-asg-lifecycle-hook-lambda-role"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect    = "Allow"
#         Principal = { Service = "lambda.amazonaws.com" }
#         Action    = "sts:AssumeRole"
#       }
#     ]
#   })
# }

# resource "aws_iam_role_policy_attachment" "al2023_asg_lifecycle_hook_lambda_logs" {
#   role       = aws_iam_role.al2023_asg_lifecycle_hook_lambda.name
#   policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
# }
