data "archive_file" "lambda_empleado" {
  type        = "zip"
  source_dir  = "${path.module}/../empleado"
  output_path = "${path.module}/bin/empleado.zip"
}

resource "aws_lambda_function" "empleado" {
  function_name    = "empleado"
  handler          = var.lambda_handler
  runtime          = var.lambda_runtime
  role             = aws_iam_role.lambda_process_exec_role.arn
  filename         = data.archive_file.lambda_empleado.output_path
  source_code_hash = data.archive_file.lambda_empleado.output_base64sha256
  timeout          = 30
  memory_size      = 256
  kms_key_arn      = aws_kms_key.lambda_env_vars_key.arn

  # Configuración de VPC
  vpc_config {
    subnet_ids         = [aws_subnet.subnet_a.id, aws_subnet.subnet_b.id]
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  # Configuración de code signing
  code_signing_config_arn = aws_lambda_code_signing_config.empleado_code_signing.arn

  # Límite de ejecución concurrente
  reserved_concurrent_executions = var.lambda_concurrency

  # Configuración de Dead Letter Queue
  dead_letter_config {
    target_arn = aws_sqs_queue.empleado_dlq.arn
  }

  # Configuración de tracing X-Ray
  tracing_config {
    mode = "Active"
  }

  # Configuración de entorno
  environment {
    variables = {
      DYNAMO_TABLE = var.dynamodb_table_name
      AWS_REGION   = var.aws_region
    }
  }

  tags = {
    Name        = "empleado"
    Environment = "dev"
  }

  depends_on = [
    aws_cloudwatch_log_group.lambda_logs,
    aws_iam_role_policy_attachment.lambda_vpc_policy_attachment,
    aws_iam_role_policy_attachment.lambda_xray_policy_attachment,
    aws_iam_role_policy_attachment.lambda_empleado_dlq_attachment
  ]
}

# Configuración de Code Signing para empleado
resource "aws_lambda_code_signing_config" "empleado_code_signing" {
  description = "Code signing config for empleado Lambda"

  allowed_publishers {
    signing_profile_version_arns = [
      aws_signer_signing_profile.empleado_signing_profile.arn
    ]
  }

  policies {
    untrusted_artifact_on_deployment = "Warn"
  }
}

resource "aws_signer_signing_profile" "empleado_signing_profile" {
  platform_id = "AWSLambda-SHA384-ECDSA"
}

# Dead Letter Queue para empleado
resource "aws_sqs_queue" "empleado_dlq" {
  name = "empleado-dlq"
  
  kms_master_key_id                 = aws_kms_key.lambda_dlq_key.id
  kms_data_key_reuse_period_seconds = 300
  
  tags = {
    Name        = "empleado-dlq"
    Environment = "dev"
  }
}

# Política para DLQ de empleado
data "aws_iam_policy_document" "lambda_empleado_dlq_policy_doc" {
  statement {
    actions = [
      "sqs:SendMessage",
      "sqs:GetQueueAttributes",
      "sqs:GetQueueUrl"
    ]
    resources = [aws_sqs_queue.empleado_dlq.arn]
  }
}

resource "aws_iam_policy" "lambda_empleado_dlq_policy" {
  name   = "lambda-empleado-dlq-policy"
  policy = data.aws_iam_policy_document.lambda_empleado_dlq_policy_doc.json
}

resource "aws_iam_role_policy_attachment" "lambda_empleado_dlq_attachment" {
  role       = aws_iam_role.lambda_process_exec_role.name
  policy_arn = aws_iam_policy.lambda_empleado_dlq_policy.arn
}