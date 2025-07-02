data "archive_file" "lambda_empleado" {
  type        = "zip"
  source_dir  = "${path.module}/../empleado"
  output_path = "${path.module}/bin/empleado.zip"
}

resource "aws_lambda_function" "empleado" {
  function_name = "empleado"
  handler       = var.lambda_handler
  runtime       = var.lambda_runtime
  role          = aws_iam_role.lambda_process_exec_role.arn
  filename      = data.archive_file.lambda_empleado.output_path
  source_code_hash = data.archive_file.lambda_empleado.output_base64sha256

  environment {
    variables = {
      DYNAMO_TABLE = var.dynamodb_table_name
    }
  }

  tags = {
    Name = "empleado"
    Environment = "dev"
  }
}