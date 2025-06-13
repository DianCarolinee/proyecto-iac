resource "aws_sqs_queue" "auditoria_queue" {
  name = "auditoria-queue"
}

data "archive_file" "lambda_nomina" {
  type        = "zip"
  source_dir  = "${path.module}/../nomina"
  output_path = "${path.module}/bin/nomina.zip"
}

resource "aws_lambda_function" "nomina" {
  function_name = "nomina"
  handler       = var.lambda_handler
  runtime       = var.lambda_runtime
  role          = aws_iam_role.lambda_process_exec_role.arn
  filename      = data.archive_file.lambda_nomina.output_path
  source_code_hash = data.archive_file.lambda_nomina.output_base64sha256

  environment {
    variables = {
      QUEUE_URL = aws_sqs_queue.auditoria_queue.id
    }
  }

  tags = {
    Name = "nomina"
    Environment = "dev"
  }
}
