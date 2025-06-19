resource "aws_kms_key" "s3_kms_key" {
  description             = "CMK para cifrar el bucket S3 process-bucket-proyecto-imagen"
  deletion_window_in_days = 10
  enable_key_rotation     = true

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

resource "aws_s3_bucket_server_side_encryption_configuration" "s3_encryption" {
  bucket = aws_s3_bucket.bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3_kms_key.arn
    }
  }
}
