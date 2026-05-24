# =============================================================
# Root Module — Outputs
# =============================================================
# Only the scheduler module is active right now.
# Outputs from other modules will be uncommented as each is built.

# ---- Scheduler ----------------------------------------------

output "scheduler_schedule_arn" {
  description = "ARN of the EventBridge schedule"
  value       = module.scheduler.schedule_arn
}

output "scheduler_group_arn" {
  description = "ARN of the EventBridge schedule group"
  value       = module.scheduler.schedule_group_arn
}

output "scheduler_role_arn" {
  description = "ARN of the IAM role used by the EventBridge Scheduler"
  value       = module.scheduler.scheduler_role_arn
}

# ---- Foundation (TODO) -------------------------------------
# output "data_bucket_name" {
#   description = "Name of the S3 data lake bucket"
#   value       = module.foundation.data_bucket_id
# }

# ---- Ingestion (TODO) --------------------------------------
# output "api_gateway_invoke_url" {
#   description = "Invoke URL for the ingestion API Gateway"
#   value       = module.ingestion.api_gateway_invoke_url
# }

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
