data "archive_file" "lambda_process" {
  type        = "zip"
  source_dir  = "${path.module}/../process"
  output_path = "${path.module}/bin/process.zip"
}

resource "aws_iam_role" "lambda_process_exec_role" {
  name = "${var.lambda_function_name}_exec_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })

  lifecycle {
    create_before_destroy = true
  }
}


resource "aws_dynamodb_table" "vision_clean_images" {
  name           = var.dynamodb_table_name
  billing_mode   = "PROVISIONED"
  read_capacity  = var.read_capacity
  write_capacity = var.write_capacity
  hash_key       = "id"

  attribute {
    name = "id"
    type = "S"
  }

  ttl {
    attribute_name = "img_name"
    enabled        = false
  }

  tags = {
    Name        = var.dynamodb_table_name
    Environment = "dev"
  }
}

resource "aws_iam_policy" "lambda_policy_process" {
  name_prefix = "${var.lambda_function_name}_"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Effect   = "Allow",
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem"
        ],
        Effect   = "Allow",
        Resource = aws_dynamodb_table.vision_clean_images.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy_attachment_process" {
  role       = aws_iam_role.lambda_process_exec_role.name
  policy_arn = aws_iam_policy.lambda_policy_process.arn
}

resource "aws_lambda_function" "process" {
  function_name    = var.lambda_function_name
  handler          = var.lambda_handler
  runtime          = var.lambda_runtime
  role             = aws_iam_role.lambda_process_exec_role.arn
  filename         = data.archive_file.lambda_process.output_path
  source_code_hash = data.archive_file.lambda_process.output_base64sha256

  environment {
    variables = {
      HELLO = "WORLD"
    }
  }

  tags = {
    Name        = var.lambda_function_name
    Environment = "dev"
  }

  depends_on = [aws_cloudwatch_log_group.lambda_logs]
}

resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${var.lambda_function_name}"
  retention_in_days = 7

  lifecycle {
    create_before_destroy = true
    ignore_changes = [name]
  }

  tags = {
    Environment = "dev"
    Function    = var.lambda_function_name
  }
}


resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowS3"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.process.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.bucket.arn
}

resource "aws_s3_bucket_notification" "aws_s3_bucket_notification" {
  bucket = aws_s3_bucket.bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.process.arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_lambda_permission.allow_s3]
}