resource "aws_sqs_queue" "auditoria_queue" {
  name = "auditoria-queue"
  
  # Habilitar encriptación con KMS
  kms_master_key_id                 = aws_kms_key.sqs_queue_key.arn
  kms_data_key_reuse_period_seconds = 300
  
  tags = {
    Name        = "auditoria-queue"
    Environment = "dev"
  }
}

data "archive_file" "lambda_nomina" {
  type        = "zip"
  source_dir  = "${path.module}/../nomina"
  output_path = "${path.module}/bin/nomina.zip"
}

resource "aws_lambda_function" "nomina" {
  function_name    = "nomina"
  handler          = var.lambda_handler
  runtime          = var.lambda_runtime
  role             = aws_iam_role.lambda_process_exec_role.arn
  filename         = data.archive_file.lambda_nomina.output_path
  source_code_hash = data.archive_file.lambda_nomina.output_base64sha256
  timeout          = 30
  memory_size      = 256
  kms_key_arn      = aws_kms_key.lambda_env_vars_key.arn

  # Configuración de VPC
  vpc_config {
    subnet_ids         = [aws_subnet.subnet_a.id, aws_subnet.subnet_b.id]
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  # Configuración de code signing
  code_signing_config_arn = aws_lambda_code_signing_config.nomina_code_signing.arn

  # Límite de ejecución concurrente
  reserved_concurrent_executions = var.lambda_concurrency

  # Configuración de Dead Letter Queue
  dead_letter_config {
    target_arn = aws_sqs_queue.nomina_dlq.arn
  }

  # Configuración de tracing X-Ray
  tracing_config {
    mode = "Active"
  }

  # Configuración de entorno
  environment {
    variables = {
      QUEUE_URL = aws_sqs_queue.auditoria_queue.id
    }
  }

  tags = {
    Name        = "nomina"
    Environment = "dev"
  }

  depends_on = [
    aws_cloudwatch_log_group.lambda_logs,
    aws_iam_role_policy_attachment.lambda_vpc_policy_attachment,
    aws_iam_role_policy_attachment.lambda_xray_policy_attachment,
    aws_iam_role_policy_attachment.lambda_nomina_dlq_attachment,
    aws_iam_role_policy_attachment.lambda_nomina_queue_policy_attachment
  ]
}

# Configuración de Code Signing para nómina
resource "aws_lambda_code_signing_config" "nomina_code_signing" {
  description = "Code signing config for nomina Lambda"

  allowed_publishers {
    signing_profile_version_arns = [
      aws_signer_signing_profile.nomina_signing_profile.arn
    ]
  }

  policies {
    untrusted_artifact_on_deployment = "Warn"
  }
}

resource "aws_signer_signing_profile" "nomina_signing_profile" {
  platform_id = "AWSLambda-SHA384-ECDSA"
}

# Dead Letter Queue para nómina
resource "aws_sqs_queue" "nomina_dlq" {
  name = "nomina-dlq"
  
  kms_master_key_id                 = aws_kms_key.lambda_dlq_key.id
  kms_data_key_reuse_period_seconds = 300
  
  tags = {
    Name        = "nomina-dlq"
    Environment = "dev"
  }
}

# Clave KMS para variables de entorno (si no existe)
resource "aws_kms_key" "lambda_env_vars_key" {
  description             = "KMS Key for Lambda environment variables encryption"
  enable_key_rotation     = true
  deletion_window_in_days = 10

  tags = {
    Name        = "lambda-env-vars-key"
    Environment = "dev"
  }
}

# Clave KMS para cola SQS (si no existe)
resource "aws_kms_key" "sqs_queue_key" {
  description             = "KMS key for SQS queue encryption"
  enable_key_rotation     = true
  deletion_window_in_days = 10
  
  tags = {
    Name        = "sqs-queue-key"
    Environment = "dev"
  }
}

# Política KMS para cola SQS
resource "aws_kms_key_policy" "sqs_queue_key_policy" {
  key_id = aws_kms_key.sqs_queue_key.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "sqs.amazonaws.com"
        },
        Action = [
          "kms:GenerateDataKey",
          "kms:Decrypt"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        },
        Action = "kms:*",
        Resource = "*"
      }
    ]
  })
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

# Política para DLQ de nómina
data "aws_iam_policy_document" "lambda_nomina_dlq_policy_doc" {
  statement {
    actions = [
      "sqs:SendMessage",
      "sqs:GetQueueAttributes",
      "sqs:GetQueueUrl"
    ]
    resources = [aws_sqs_queue.nomina_dlq.arn]
  }
}

resource "aws_iam_policy" "lambda_nomina_dlq_policy" {
  name   = "lambda-nomina-dlq-policy"
  policy = data.aws_iam_policy_document.lambda_nomina_dlq_policy_doc.json
}

resource "aws_iam_role_policy_attachment" "lambda_nomina_dlq_attachment" {
  role       = aws_iam_role.lambda_process_exec_role.name
  policy_arn = aws_iam_policy.lambda_nomina_dlq_policy.arn
}

# Política para la cola SQS de auditoría
data "aws_iam_policy_document" "lambda_nomina_queue_policy_doc" {
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

resource "aws_iam_policy" "lambda_nomina_queue_policy" {
  name   = "lambda-nomina-queue-policy"
  policy = data.aws_iam_policy_document.lambda_nomina_queue_policy_doc.json
}

resource "aws_iam_role_policy_attachment" "lambda_nomina_queue_policy_attachment" {
  role       = aws_iam_role.lambda_process_exec_role.name
  policy_arn = aws_iam_policy.lambda_nomina_queue_policy.arn
}

data "aws_caller_identity" "current" {}