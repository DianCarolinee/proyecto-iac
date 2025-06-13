data "archive_file" "lambda_auditoria" {
  type        = "zip"
  source_dir  = "${path.module}/../auditoria"
  output_path = "${path.module}/bin/auditoria.zip"
}

resource "aws_lambda_function" "auditoria" {
  function_name = "auditoria"
  handler       = var.lambda_handler
  runtime       = var.lambda_runtime
  role          = aws_iam_role.lambda_process_exec_role.arn
  filename      = data.archive_file.lambda_auditoria.output_path
  source_code_hash = data.archive_file.lambda_auditoria.output_base64sha256

  tags = {
    Name = "auditoria"
    Environment = "dev"
  }
}

resource "aws_lambda_event_source_mapping" "sqs_to_auditoria" {
  event_source_arn = aws_sqs_queue.auditoria_queue.arn
  function_name    = aws_lambda_function.auditoria.arn
  batch_size       = 1
  enabled          = true
}
