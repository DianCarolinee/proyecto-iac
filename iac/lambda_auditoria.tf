data "archive_file" "lambda_auditoria" {
  type        = "zip"
  source_dir  = "${path.module}/../auditoria"
  output_path = "${path.module}/bin/auditoria.zip"
}

data "aws_caller_identity" "current" {}

resource "aws_lambda_function" "auditoria" {
  function_name    = "auditoria"
  handler          = var.lambda_handler
  runtime          = var.lambda_runtime
  role             = aws_iam_role.lambda_process_exec_role.arn
  filename         = data.archive_file.lambda_auditoria.output_path
  source_code_hash = data.archive_file.lambda_auditoria.output_base64sha256
  timeout          = 30
  memory_size      = 256
  kms_key_arn      = aws_kms_key.lambda_env_vars_key.arn

  # Configuración de VPC
  vpc_config {
    subnet_ids         = [aws_subnet.subnet_a.id, aws_subnet.subnet_b.id]
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  # Configuración de code signing
  code_signing_config_arn = aws_lambda_code_signing_config.auditoria_code_signing.arn

  # Límite de ejecución concurrente
  reserved_concurrent_executions = var.lambda_concurrency

  # Configuración de Dead Letter Queue
  dead_letter_config {
    target_arn = aws_sqs_queue.auditoria_dlq.arn
  }

  # Configuración de tracing X-Ray
  tracing_config {
    mode = "Active"
  }

  # Configuración de entorno
  environment {
    variables = {
      AWS_REGION = var.aws_region
    }
  }

  tags = {
    Name        = "auditoria"
    Environment = "dev"
  }

  depends_on = [
    aws_cloudwatch_log_group.lambda_logs,
    aws_iam_role_policy_attachment.lambda_vpc_policy_attachment,
    aws_iam_role_policy_attachment.lambda_xray_policy_attachment,
    aws_iam_role_policy_attachment.lambda_auditoria_dlq_attachment,
    aws_iam_role_policy_attachment.lambda_auditoria_queue_policy_attachment
  ]
}

# Configuración de Code Signing
resource "aws_lambda_code_signing_config" "auditoria_code_signing" {
  description = "Code signing config for auditoria Lambda"

  allowed_publishers {
    signing_profile_version_arns = [
      aws_signer_signing_profile.auditoria_signing_profile.arn
    ]
  }

  policies {
    untrusted_artifact_on_deployment = "Warn"
  }
}

resource "aws_signer_signing_profile" "auditoria_signing_profile" {
  platform_id = "AWSLambda-SHA384-ECDSA"
}

# Cola SQS principal (encriptada)
resource "aws_sqs_queue" "auditoria_queue" {
  name = "auditoria-queue"
  
  kms_master_key_id                 = aws_kms_key.sqs_queue_key.arn
  kms_data_key_reuse_period_seconds = 300
  
  tags = {
    Name        = "auditoria-queue"
    Environment = "dev"
  }
}

# Configuración de Event Source Mapping para SQS
resource "aws_lambda_event_source_mapping" "sqs_to_auditoria" {
  event_source_arn = aws_sqs_queue.auditoria_queue.arn
  function_name    = aws_lambda_function.auditoria.arn
  batch_size       = 1
  enabled          = true
}

# Dead Letter Queue para auditoría
resource "aws_sqs_queue" "auditoria_dlq" {
  name = "auditoria-dlq"
  
  kms_master_key_id                 = aws_kms_key.lambda_dlq_key.id
  kms_data_key_reuse_period_seconds = 300
  
  tags = {
    Name        = "auditoria-dlq"
    Environment = "dev"
  }
}

# Claves KMS con políticas definidas
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
        Sid    = "Allow Lambda Service to use the key",
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
    Name        = "lambda-env-vars-key"
    Environment = "dev"
  }
}

resource "aws_kms_key" "sqs_queue_key" {
  description             = "KMS key for SQS queue encryption"
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
        Sid    = "Allow SQS Service to use the key",
        Effect = "Allow",
        Principal = {
          Service = "sqs.amazonaws.com"
        },
        Action = [
          "kms:GenerateDataKey",
          "kms:Decrypt"
        ],
        Resource = "*"
      }
    ]
  })
  
  tags = {
    Name        = "sqs-queue-key"
    Environment = "dev"
  }
}

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
        Sid    = "Allow SQS Service to use the key",
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
    Name        = "lambda-dlq-key"
    Environment = "dev"
  }
}

# Adjuntos de políticas IAM
resource "aws_iam_role_policy_attachment" "lambda_vpc_policy_attachment" {
  role       = aws_iam_role.lambda_process_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_xray_policy_attachment" {
  role       = aws_iam_role.lambda_process_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

# Política para DLQ
data "aws_iam_policy_document" "lambda_auditoria_dlq_policy_doc" {
  statement {
    actions = [
      "sqs:SendMessage",
      "sqs:GetQueueAttributes",
      "sqs:GetQueueUrl"
    ]
    resources = [aws_sqs_queue.auditoria_dlq.arn]
  }
}

resource "aws_iam_policy" "lambda_auditoria_dlq_policy" {
  name   = "lambda-auditoria-dlq-policy"
  policy = data.aws_iam_policy_document.lambda_auditoria_dlq_policy_doc.json
}

resource "aws_iam_role_policy_attachment" "lambda_auditoria_dlq_attachment" {
  role       = aws_iam_role.lambda_process_exec_role.name
  policy_arn = aws_iam_policy.lambda_auditoria_dlq_policy.arn
}

# Política para la cola SQS principal
data "aws_iam_policy_document" "lambda_auditoria_queue_policy_doc" {
  statement {
    actions = [
      "sqs:SendMessage",
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
      "kms:Decrypt"
    ]
    resources = [
      aws_sqs_queue.auditoria_queue.arn,
      aws_kms_key.sqs_queue_key.arn
    ]
  }
}

resource "aws_iam_policy" "lambda_auditoria_queue_policy" {
  name   = "lambda-auditoria-queue-policy"
  policy = data.aws_iam_policy_document.lambda_auditoria_queue_policy_doc.json
}

resource "aws_iam_role_policy_attachment" "lambda_auditoria_queue_policy_attachment" {
  role       = aws_iam_role.lambda_process_exec_role.name
  policy_arn = aws_iam_policy.lambda_auditoria_queue_policy.arn
}