# Define Provider as aws
provider "aws" {
  region                  = var.aws_region
  shared_credentials_file = "/Users/niuniu/.aws/credentials"
}

# Define Main VPC
#resource "aws_vpc" "main_vpc" {
#  cidr_block = "172.31.0.0/16"
#}

# Define public subnet
#resource "aws_subnet" "main_subnet" {
#  vpc_id     = aws_vpc.main_vpc.id
#  cidr_block = "172.31.0.0/20"

#  tags = {
#    Name = "Main_Subnet"
#  }
#}

#resource "aws_security_group" "lambda_security_group" {
#  name        = "lambda_security_group"
#  description = "security group for lambda function"
#  vpc_id      = aws_vpc.main_vpc.id
#}

# Define IAM role for lambda function
resource "aws_iam_role" "iam_for_lambda" {
  name = "iam_for_lambda"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

# This is to optionally manage the CloudWatch Log Group for the Lambda Function.
# If skipping this resource configuration, also add "logs:CreateLogGroup" to the IAM policy below.
resource "aws_cloudwatch_log_group" "lambda_cloudwatch" {
  name              = "/aws/lambda/${var.lambda_function_name}"
  retention_in_days = 14
}

# See also the following AWS managed policy: AWSLambdaBasicExecutionRole
resource "aws_iam_policy" "lambda_logging" {
  name        = "lambda_logging"
  path        = "/"
  description = "IAM policy for logging from a lambda"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*",
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = aws_iam_policy.lambda_logging.arn
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/greet_lambda.py"
  output_path = "${path.module}/script.zip"
}

# Define AWS Lambda function
resource "aws_lambda_function" "lambda_greeting" {
  description      = "Greet lambda function"
  role             = aws_iam_role.iam_for_lambda.arn
  function_name    = var.lambda_function_name
  handler          = "${var.lambda_function_name}.lambda_handler"
  runtime          = "python3.8"

  #vpc_config {
  #  subnet_ids = [aws_subnet.main_subnet.id]
  #  security_group_ids = [aws_security_group.lambda_security_group.id]
  #}
  filename         = "script.zip"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      greeting = "Hello World"
    }
  }

  depends_on = [aws_cloudwatch_log_group.lambda_cloudwatch, aws_iam_role_policy_attachment.lambda_logs]
}