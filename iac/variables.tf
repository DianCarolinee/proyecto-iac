# 1. Configuración básica
variable "environment" {
  description = "Entorno de despliegue (dev/staging/prod)"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "Región de AWS donde se desplegarán los recursos"
  type        = string
  default     = "us-east-2"
}

# 2. Configuración de Lambda
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

variable "lambda_memory_size" {
  description = "Memoria asignada a la función Lambda en MB (128-10240)"
  type        = number
  default     = 512
}

variable "lambda_timeout" {
  description = "Tiempo máximo de ejecución en segundos (1-900)"
  type        = number
  default     = 30
}

variable "lambda_concurrency" {
  description = "Límite de ejecuciones concurrentes"
  type        = number
  default     = 100
}

variable "allowed_http_ips" {
  description = "Lista de IPs permitidas para acceso HTTP"
  type        = list(string)
  default     = []  # Definir tus IPs específicas aquí
}

variable "allowed_https_ips" {
  description = "Lista de IPs permitidas para acceso HTTPS"
  type        = list(string)
  default     = []  # Definir tus IPs específicas aquí
}

# 3. Configuración de DynamoDB
variable "dynamodb_table_name" {
  description = "Nombre de la tabla DynamoDB"
  type        = string
  default     = "VisionCleanImages"
}

variable "read_capacity" {
  description = "Unidades de capacidad de lectura para DynamoDB"
  type        = number
  default     = 20
}

variable "write_capacity" {
  description = "Unidades de capacidad de escritura para DynamoDB"
  type        = number
  default     = 20
}

variable "dynamodb_billing_mode" {
  description = "Modo de facturación (PROVISIONED o PAY_PER_REQUEST)"
  type        = string
  default     = "PROVISIONED"
}

# 4. Configuración de VPC
variable "vpc_enabled" {
  description = "Habilitar despliegue en VPC"
  type        = bool
  default     = true
}

# 5. Configuración de S3 (para el trigger)
variable "s3_bucket_name" {
  description = "Nombre del bucket S3 para imágenes"
  type        = string
  default     = "process-bucket-proyecto-imagen" # O elimina default para hacerlo obligatorio
}

variable "s3_event_prefix" {
  description = "Prefijo para filtrar objetos S3 que disparan la Lambda"
  type        = string
  default     = "uploads/"
}

variable "s3_event_suffix" {
  description = "Sufijo para filtrar objetos S3 que disparan la Lambda"
  type        = string
  default     = ".jpg"
}

# 6. Configuración de seguridad
variable "enable_code_signing" {
  description = "Habilitar firma de código para Lambda"
  type        = bool
  default     = false
}

# 7. Configuración de logs
variable "log_retention_days" {
  description = "Días de retención para logs de CloudWatch"
  type        = number
  default     = 14
}

