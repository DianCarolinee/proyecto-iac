resource "aws_kms_key" "s3_kms_key" {
  description             = "CMK para cifrar el bucket S3 process-bucket-proyecto-imagen"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  # Política KMS para cumplir con CKV2_AWS_64
  policy = jsonencode({
    Version = "2012-10-17",
    Id      = "key-default-1",
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
        Sid    = "Allow S3 to use the key",
        Effect = "Allow",
        Principal = {
          Service = "s3.amazonaws.com"
        },
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ],
        Resource = "*"
      },
      {
        Sid    = "Allow administration of the key",
        Effect = "Allow",
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/terraform"
        },
        Action = [
          "kms:Create*",
          "kms:Describe*",
          "kms:Enable*",
          "kms:List*",
          "kms:Put*",
          "kms:Update*",
          "kms:Revoke*",
          "kms:Disable*",
          "kms:Get*",
          "kms:Delete*",
          "kms:TagResource",
          "kms:UntagResource",
          "kms:ScheduleKeyDeletion",
          "kms:CancelKeyDeletion"
        ],
        Resource = "*"
      }
    ]
  })

  tags = {
    Environment = "dev"
    Purpose     = "s3-encryption"
  }
}

resource "aws_s3_bucket" "bucket" {
  bucket = "process-bucket-proyecto-imagen"

  tags = {
    Environment = "dev"
  }
}

# Configuración de versionado para cumplir con CKV_AWS_21
resource "aws_s3_bucket_versioning" "versioning" {
  bucket = aws_s3_bucket.bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Configuración de encriptación
resource "aws_s3_bucket_server_side_encryption_configuration" "s3_encryption" {
  bucket = aws_s3_bucket.bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3_kms_key.arn
    }
  }
}

# Bloqueo de acceso público para cumplir con CKV2_AWS_6
resource "aws_s3_bucket_public_access_block" "public_access" {
  bucket = aws_s3_bucket.bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "lifecycle" {
  bucket = aws_s3_bucket.bucket.id

  rule {
    id = "auto-cleanup"
    
    # Requerido por CKV_AWS_300
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
    
    # Configuración existente de expiración
    expiration {
      days = 365
    }

    # Configuración existente de versiones no actuales
    noncurrent_version_expiration {
      noncurrent_days = 90
    }

    status = "Enabled"
  }
}

# Bucket para logs de acceso (requerido para CKV_AWS_18)
resource "aws_s3_bucket" "access_logs" {
  bucket = "${aws_s3_bucket.bucket.id}-access-logs"
}

# Habilitar logging de acceso para cumplir con CKV_AWS_18
resource "aws_s3_bucket_logging" "logging" {
  bucket        = aws_s3_bucket.bucket.id
  target_bucket = aws_s3_bucket.access_logs.id
  target_prefix = "s3-access-logs/"
}

# Configuración de replicación entre regiones para cumplir con CKV_AWS_144
resource "aws_s3_bucket_replication_configuration" "replication" {
  depends_on = [
    aws_s3_bucket_versioning.versioning,
    aws_s3_bucket.access_logs
  ]
  
  role   = aws_iam_role.replication.arn
  bucket = aws_s3_bucket.bucket.id

  rule {
    id = "cross-region-replication"
    
    destination {
      bucket        = "arn:aws:s3:::${aws_s3_bucket.bucket.id}-replica" # Necesitarás crear este bucket
      storage_class = "STANDARD"
    }

    status = "Enabled"
  }
}

# Rol IAM para replicación
resource "aws_iam_role" "replication" {
  name = "s3-replication-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "s3.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_policy" "replication" {
  name = "s3-replication-policy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:GetReplicationConfiguration",
          "s3:ListBucket"
        ],
        Resource = [aws_s3_bucket.bucket.arn]
      },
      {
        Effect = "Allow",
        Action = [
          "s3:GetObjectVersion",
          "s3:GetObjectVersionAcl",
          "s3:GetObjectVersionTagging"
        ],
        Resource = ["${aws_s3_bucket.bucket.arn}/*"]
      },
      {
        Effect = "Allow",
        Action = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete",
          "s3:ReplicateTags"
        ],
        Resource = ["arn:aws:s3:::${aws_s3_bucket.bucket.id}-replica/*"]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "replication" {
  role       = aws_iam_role.replication.name
  policy_arn = aws_iam_policy.replication.arn
}

# Necesitarás agregar esto en tu data.tf o variables.tf
data "aws_caller_identity" "current" {}