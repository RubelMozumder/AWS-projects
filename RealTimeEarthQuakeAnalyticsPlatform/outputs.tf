# =============================================================
# Root Module — Outputs
# =============================================================
# Only the scheduler module is active right now.
# Outputs from other modules will be uncommented as each is built.

# ---- Scheduler ----------------------------------------------

# output "scheduler_schedule_arn" {
#   description = "ARN of the EventBridge schedule"
#   value       = module.scheduler.schedule_arn
# }
# 
# output "scheduler_group_arn" {
#   description = "ARN of the EventBridge schedule group"
#   value       = module.scheduler.schedule_group_arn
# }
# 
# output "scheduler_role_arn" {
#   description = "ARN of the IAM role used by the EventBridge Scheduler"
#   value       = module.scheduler.scheduler_role_arn
# }

# ---- Foundation -------------------------------------
output "kms_key_arn" {
  description = "ARN of the KMS CMK used for encryption"
  value       = module.foundation.kms_key_arn
}

output "kms_alias_arn" {
  description = "ARN of the KMS key alias"
  value       = module.foundation.kms_alias_arn
}

output "kms_key_id" {
  description = "Key ID of the KMS CMK, used in IAM policy conditions"
  value       = module.foundation.kms_key_id
}

# ---- S3 Data Lake -------------------------------------------
output "data_bucket_arn" {
  description = "ARN of the S3 data lake bucket"
  value       = module.foundation.data_bucket_arn
}

output "data_bucket_name" {
  description = "Name of the S3 data lake bucket"
  value       = module.foundation.data_bucket_id
}

output "data_bucket_domain_name" {
  description = "Regional domain name of the S3 data lake bucket, used for direct URL construction"
  value       = module.foundation.data_bucket_domain_name
}

# ----- S3 and DynamoDB Terraform states --------------------------------------

output "terraform_state_bucket_id" {
  description = "Name of the S3 bucket used for Terraform state storage"
  value       = module.foundation.terraform_state_bucket_id
}

output "terraform_state_bucket_arn" {
  description = "ARN of the S3 bucket used for Terraform state storage"
  value       = module.foundation.terraform_state_bucket_arn
}

output "terraform_lock_table_name" {
  description = "Name of the DynamoDB table used for Terraform state locking"
  value       = module.foundation.terraform_lock_table_name
}

output "terraform_lock_table_arn" {
  description = "ARN of the DynamoDB table used for Terraform state locking"
  value       = module.foundation.terraform_lock_table_arn
}

# ---- Ingestion ----------------------------------------------

output "api_gateway_invoke_url" {
  description = "Full invoke URL for POST /ingest. Set as INGEST_API_URL in the collector Lambda."
  value       = module.ingestion.api_gateway_invoke_url
}

output "firehose_stream_name" {
  description = "Name of the Kinesis Firehose raw delivery stream."
  value       = module.ingestion.firehose_stream_name
}

# ---- Processing (TODO) -------------------------------------
# output "collector_lambda_name" {
#   description = "Name of the Collector Lambda function"
#   value       = module.processing.collector_lambda_name
# }

# ---- Analytics (TODO) --------------------------------------
# output "athena_workgroup_name" {
#   description = "Name of the Athena workgroup"
#   value       = module.analytics.athena_workgroup_name
# }
