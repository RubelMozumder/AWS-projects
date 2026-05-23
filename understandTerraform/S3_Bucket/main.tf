resource "aws_s3_bucket" "s3_bucket_with_terraform" {
  bucket = "s3-bucket-with-terraform-321"

  tags = {
    Name        = "s3-bucket-with-terraform-321"
    Environment = "dev"
    ManagedBy   = "Terraform"
  }
}

# Block public access — a good habit for every bucket
resource "aws_s3_bucket_public_access_block" "s3_bucket_with_terraform" {
  bucket = aws_s3_bucket.s3_bucket_with_terraform.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Print the bucket name after apply
output "bucket_name" {
  value = aws_s3_bucket.s3_bucket_with_terraform.id
}