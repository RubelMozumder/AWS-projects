# =============================================================
# Module: foundation — Outputs
# =============================================================
# These values are consumed by every other module.
# The dependency chain is:
#
#   foundation outputs
#       │
#       ├──► ingestion module  (data_bucket_id, data_bucket_arn, kms_key_arn)
#       ├──► processing module (data_bucket_id)
#       ├──► analytics module  (data_bucket_id, data_bucket_arn, kms_key_arn)
#       └──► observability     (data_bucket_id)

# ---- KMS ----------------------------------------------------

output "kms_key_arn" {
  description = "ARN of the KMS CMK. Passed to Firehose, Glue, and Athena for consistent encryption."
  value       = aws_kms_key.main.arn
}

output "kms_key_id" {
  description = "Key ID of the KMS CMK. Used when referencing the key in IAM policy conditions."
  value       = aws_kms_key.main.key_id
}

output "kms_alias_arn" {
  description = "ARN of the KMS key alias. Human-readable reference for the AWS console."
  value       = aws_kms_alias.main.arn
}

# ---- S3 Data Lake -------------------------------------------

output "data_bucket_id" {
  description = "Name (ID) of the S3 data lake bucket. Used in IAM policies and service configurations."
  value       = aws_s3_bucket.data_lake.id
}

output "data_bucket_arn" {
  description = "ARN of the S3 data lake bucket. Used in IAM policy Resource blocks."
  value       = aws_s3_bucket.data_lake.arn
}

output "data_bucket_domain_name" {
  description = "Regional domain name of the data lake bucket. Used for direct S3 URL construction."
  value       = aws_s3_bucket.data_lake.bucket_regional_domain_name
}

output "raw_data_prefix" {
  description = "S3 key prefix for raw earthquake records. Passed to Firehose as the delivery prefix."
  value       = var.raw_data_prefix
}

output "processed_data_prefix" {
  description = "S3 key prefix for processed Parquet records. Passed to Firehose transformation output."
  value       = var.processed_data_prefix
}

output "athena_results_prefix" {
  description = "S3 key prefix for Athena query result files. Passed to the Athena workgroup configuration."
  value       = var.athena_results_prefix
}

# ---- S3 Terraform State -------------------------------------

output "terraform_state_bucket_id" {
  description = "Name of the Terraform state S3 bucket. Copy this into backend.tf after foundation is deployed."
  value       = aws_s3_bucket.terraform_state.id
}

output "terraform_state_bucket_arn" {
  description = "ARN of the Terraform state S3 bucket."
  value       = aws_s3_bucket.terraform_state.arn
}

# ---- DynamoDB Lock ------------------------------------------

output "terraform_lock_table_name" {
  description = "Name of the DynamoDB state lock table. Copy this into backend.tf after foundation is deployed."
  value       = aws_dynamodb_table.terraform_lock.name
}

output "terraform_lock_table_arn" {
  description = "ARN of the DynamoDB state lock table."
  value       = aws_dynamodb_table.terraform_lock.arn
}

# ---- Convenience output for backend.tf migration ------------

output "backend_config_hint" {
  description = <<-EOT
    After `terraform apply` on the foundation module, copy these values
    into backend.tf and run `terraform init -migrate-state`:

      terraform {
        backend "s3" {
          bucket         = "<terraform_state_bucket_id>"
          key            = "eq-analytics/dev/terraform.tfstate"
          region         = "<aws_region>"
          dynamodb_table = "<terraform_lock_table_name>"
          encrypt        = true
          kms_key_id     = "<kms_key_arn>"
        }
      }
  EOT
  value = {
    bucket         = aws_s3_bucket.terraform_state.id
    dynamodb_table = aws_dynamodb_table.terraform_lock.name
    kms_key_id     = aws_kms_key.main.arn
  }
}
