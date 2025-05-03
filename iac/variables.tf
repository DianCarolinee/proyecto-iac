variable "lambda_function_name" {
  description = "Nombre de la función Lambda"
  type        = string
  default     = "process"
}

variable "lambda_handler" {
  description = "Archivo y función handler de Lambda"
  type        = string
  default     = "main.handler"
}

variable "lambda_runtime" {
  description = "Versión de Python para Lambda"
  type        = string
  default     = "python3.10"
}

variable "dynamodb_table_name" {
  description = "Nombre de la tabla DynamoDB"
  type        = string
  default     = "VisionCleanImages"
}

variable "read_capacity" {
  description = "Capacidad de lectura para DynamoDB"
  type        = number
  default     = 20
}

variable "write_capacity" {
  description = "Capacidad de escritura para DynamoDB"
  type        = number
  default     = 20
}
