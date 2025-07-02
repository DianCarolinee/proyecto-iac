# Bucket principal S3
resource "aws_s3_bucket" "bucket" {
  bucket = "process-bucket-proyecto-imagen"
  tags = {
    Environment = "dev"
  }
}

# Versionado para bucket principal
resource "aws_s3_bucket_versioning" "versioning" {
  bucket = aws_s3_bucket.bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Bloqueo de acceso público para bucket principal
resource "aws_s3_bucket_public_access_block" "public_access" {
  bucket = aws_s3_bucket.bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle configuration para bucket principal
resource "aws_s3_bucket_lifecycle_configuration" "lifecycle" {
  bucket = aws_s3_bucket.bucket.id

  rule {
    id = "auto-cleanup"
    
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
    
    expiration {
      days = 365
    }

    noncurrent_version_expiration {
      noncurrent_days = 90
    }

    status = "Enabled"
  }
}

# Bucket para access logs
resource "aws_s3_bucket" "access_logs" {
  bucket = "${aws_s3_bucket.bucket.id}-access-logs"
  tags = {
    Environment = "dev"
    Purpose     = "access-logs"
  }
}

# Versionado para bucket de logs
resource "aws_s3_bucket_versioning" "access_logs_versioning" {
  bucket = aws_s3_bucket.access_logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Encriptación para bucket de logs
resource "aws_s3_bucket_server_side_encryption_configuration" "access_logs_encryption" {
  bucket = aws_s3_bucket.access_logs.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Bloqueo de acceso público para bucket de logs
resource "aws_s3_bucket_public_access_block" "access_logs_public_access" {
  bucket = aws_s3_bucket.access_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle para bucket de logs
resource "aws_s3_bucket_lifecycle_configuration" "access_logs_lifecycle" {
  bucket = aws_s3_bucket.access_logs.id
  rule {
    id = "log-retention"
    expiration {
      days = 365
    }
    status = "Enabled"
  }
}

# Configuración de logging para bucket principal
resource "aws_s3_bucket_logging" "logging" {
  bucket        = aws_s3_bucket.bucket.id
  target_bucket = aws_s3_bucket.access_logs.id
  target_prefix = "s3-access-logs/"
}

# Notificaciones de eventos para bucket de logs
resource "aws_sns_topic" "access_logs_notifications" {
  name = "s3-access-logs-notifications"
}

resource "aws_s3_bucket_notification" "access_logs_notification" {
  bucket = aws_s3_bucket.access_logs.id
  topic {
    topic_arn     = aws_sns_topic.access_logs_notifications.arn
    events        = ["s3:ObjectCreated:*"]
    filter_suffix = ".log"
  }
}
