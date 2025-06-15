data "archive_file" "lambda_process" {
  type        = "zip"
  source_dir  = "${path.module}/../process"
  output_path = "${path.module}/bin/process.zip"
}

data "aws_caller_identity" "current" {}

# Crear un perfil de firma de código para Lambda
resource "aws_lambda_code_signing_config" "lambda_code_signing_config" {
  description = "Code signing config for Lambda function"

  allowed_publishers {
    signing_profile_version_arns = [
      aws_signer_signing_profile.lambda_signing_profile.arn
    ]
  }

  policies {
    untrusted_artifact_on_deployment = "Warn"
  }
}

resource "aws_signer_signing_profile" "lambda_signing_profile" {
  platform_id = "AWSLambda-SHA384-ECDSA"
}

# KMS Key para firma de código
resource "aws_kms_key" "lambda_code_signing_key" {
  description             = "KMS Key for Lambda Code Signing"
  enable_key_rotation     = true
  deletion_window_in_days = 10

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "Enable IAM User Permissions",
        Effect = "Allow",
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        },
        Action   = "kms:*",
        Resource = "*"
      },
      {
        Sid    = "Allow Lambda Service to use the key",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        },
        Action = [
          "kms:GetPublicKey",
          "kms:Sign",
          "kms:Verify"
        ],
        Resource = "*"
      },
      {
        Sid    = "Allow Signer Service to use the key",
        Effect = "Allow",
        Principal = {
          Service = "signer.amazonaws.com"
        },
        Action = [
          "kms:GetPublicKey",
          "kms:Sign"
        ],
        Resource = "*"
      }
    ]
  })

  tags = {
    Name = "lambda-code-signing-key"
  }
}

# KMS Key para DynamoDB
resource "aws_kms_key" "dynamodb_kms_key" {
  description             = "CMK para cifrar la tabla DynamoDB vision_clean_images"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "Enable IAM User Permissions",
        Effect = "Allow",
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        },
        Action   = "kms:*",
        Resource = "*"
      },
      {
        Sid    = "Allow DynamoDB to use the key",
        Effect = "Allow",
        Principal = {
          Service = "dynamodb.amazonaws.com"
        },
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ],
        Resource = "*"
      }
    ]
  })

  tags = {
    Environment = "dev"
    Purpose     = "dynamodb-encryption"
  }
}

# KMS Key para DLQ
resource "aws_kms_key" "lambda_dlq_key" {
  description             = "KMS Key for Lambda DLQ encryption"
  enable_key_rotation     = true
  deletion_window_in_days = 10

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "Enable IAM User Permissions",
        Effect = "Allow",
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        },
        Action   = "kms:*",
        Resource = "*"
      },
      {
        Sid    = "Allow SQS to use the key",
        Effect = "Allow",
        Principal = {
          Service = "sqs.amazonaws.com"
        },
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey*"
        ],
        Resource = "*"
      }
    ]
  })

  tags = {
    Name        = "${var.lambda_function_name}-dlq-key"
    Environment = "dev"
  }
}

# IAM Role para Lambda
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
}

# Tabla DynamoDB
resource "aws_dynamodb_table" "vision_clean_images" {
  name           = var.dynamodb_table_name
  billing_mode   = "PROVISIONED"
  read_capacity  = var.read_capacity
  write_capacity = var.write_capacity
  hash_key       = "id"
  
  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.dynamodb_kms_key.arn
  }
  
  attribute {
    name = "id"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
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

# IAM Policy para Lambda
resource "aws_iam_policy" "lambda_policy_process" {
  name = "${var.lambda_function_name}_policy"
  
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
        Resource = "arn:aws:logs:${var.aws_region}:*:log-group:/aws/lambda/${var.lambda_function_name}:*"
      },
      {
        Action = [
          "dynamodb:PutItem",
          "dynamodb:UpdateItem"
        ],
        Effect   = "Allow",
        Resource = aws_dynamodb_table.vision_clean_images.arn,
        Condition = {
          StringEquals = {
            "dynamodb:LeadingKeys" = ["${var.environment}-*"]
          }
        }
      },
      {
        Action = [
          "dynamodb:GetItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ],
        Effect   = "Allow",
        Resource = aws_dynamodb_table.vision_clean_images.arn
      },
      {
        Effect = "Allow",
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface",
          "ec2:AssignPrivateIpAddresses",
          "ec2:UnassignPrivateIpAddresses"
        ],
        Resource = "*",
        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = [var.aws_region]
          }
        }
      },
      {
        Effect = "Allow",
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ],
        Resource = [
          aws_kms_key.dynamodb_kms_key.arn,
          aws_kms_key.lambda_dlq_key.arn,
          aws_kms_key.lambda_env_vars_key.arn,
          aws_kms_key.lambda_code_signing_key.arn
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "sqs:SendMessage"
        ],
        Resource = [
          aws_sqs_queue.lambda_dlq.arn
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "signer:GetSigningProfile",
          "signer:DescribeSigningJob"
        ],
        Resource = "*"
      }
    ]
  })
}

# KMS para variables de entorno Lambda
resource "aws_kms_key" "lambda_env_vars_key" {
  description             = "KMS Key for Lambda environment variables encryption"
  enable_key_rotation     = true
  deletion_window_in_days = 10

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "Enable IAM User Permissions",
        Effect = "Allow",
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        },
        Action   = "kms:*",
        Resource = "*"
      },
      {
        Sid    = "Allow Lambda to use the key",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        },
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ],
        Resource = "*"
      }
    ]
  })

  tags = {
    Name        = "${var.lambda_function_name}-env-vars-key"
    Environment = "dev"
  }
}

# Adjuntar política al rol
resource "aws_iam_role_policy_attachment" "lambda_policy_attachment_process" {
  role       = aws_iam_role.lambda_process_exec_role.name
  policy_arn = aws_iam_policy.lambda_policy_process.arn
}

# Dead Letter Queue (DLQ)
resource "aws_sqs_queue" "lambda_dlq" {
  name = "${var.lambda_function_name}-dlq"
  
  kms_master_key_id                 = aws_kms_key.lambda_dlq_key.id
  kms_data_key_reuse_period_seconds = 300
  
  tags = {
    Name        = "${var.lambda_function_name}-dlq"
    Environment = "dev"
  }
}

# Función Lambda principal
resource "aws_lambda_function" "process" {
  function_name    = var.lambda_function_name
  handler          = var.lambda_handler
  runtime          = var.lambda_runtime
  role             = aws_iam_role.lambda_process_exec_role.arn
  filename         = data.archive_file.lambda_process.output_path
  source_code_hash = data.archive_file.lambda_process.output_base64sha256
  timeout          = 30
  memory_size      = 256

  reserved_concurrent_executions = var.lambda_concurrency

  vpc_config {
    subnet_ids         = [aws_subnet.subnet_a.id, aws_subnet.subnet_b.id]
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  code_signing_config_arn = aws_lambda_code_signing_config.lambda_code_signing_config.arn

  dead_letter_config {
    target_arn = aws_sqs_queue.lambda_dlq.arn
  }

  environment {
    variables = {
      DYNAMODB_TABLE = var.dynamodb_table_name
      AWS_REGION     = var.aws_region
    }
  }

  tracing_config {
    mode = "Active"
  }

  tags = {
    Name        = var.lambda_function_name
    Environment = "dev"
  }

  depends_on = [
    aws_cloudwatch_log_group.lambda_logs,
    aws_iam_role_policy_attachment.lambda_policy_attachment_process
  ]

  kms_key_arn = aws_kms_key.lambda_env_vars_key.arn
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${var.lambda_function_name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = aws_kms_key.cloudwatch_logs_key.arn
  
  tags = {
    Environment = "dev"
    Function    = var.lambda_function_name
  }
}

# KMS para CloudWatch Logs
resource "aws_kms_key" "cloudwatch_logs_key" {
  description             = "KMS Key for CloudWatch Logs encryption"
  enable_key_rotation     = true
  deletion_window_in_days = 10

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "Enable IAM User Permissions",
        Effect = "Allow",
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        },
        Action   = "kms:*",
        Resource = "*"
      },
      {
        Sid    = "Allow CloudWatch to use the key",
        Effect = "Allow",
        Principal = {
          Service = "logs.${var.aws_region}.amazonaws.com"
        },
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ],
        Resource = "*",
        Condition = {
          ArnLike = {
            "kms:EncryptionContext:aws:logs:arn" = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:*"
          }
        }
      }
    ]
  })

  tags = {
    Name        = "cloudwatch-logs-key"
    Environment = "dev"
  }
}

# Permiso para invocación desde S3
resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.process.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.bucket.arn
}

# Notificación de S3
resource "aws_s3_bucket_notification" "aws_s3_bucket_notification" {
  bucket = aws_s3_bucket.bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.process.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = var.s3_event_prefix
    filter_suffix       = var.s3_event_suffix
  }

  depends_on = [aws_lambda_permission.allow_s3]
}