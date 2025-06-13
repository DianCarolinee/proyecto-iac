output "lambda_function_name" {
  description = "Nombre de la función Lambda creada"
  value       = aws_lambda_function.process.function_name
}

output "lambda_function_arn" {
  description = "ARN de la función Lambda"
  value       = aws_lambda_function.process.arn
}

output "dynamodb_table_name" {
  description = "Nombre de la tabla DynamoDB"
  value       = aws_dynamodb_table.vision_clean_images.name
}

output "dynamodb_table_arn" {
  description = "ARN de la tabla DynamoDB"
  value       = aws_dynamodb_table.vision_clean_images.arn
}
