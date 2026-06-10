# =============================================================
# Central Orchestration — Earthquake Analytics Platform
# =============================================================
# This file is the single entry point for the entire infrastructure.
# Each module below is an independent, reusable Terraform module
# located in ./modules/<name>/.
#
# Build order (each depends on the one above it):
#   1. foundation    → S3, IAM, KMS, Terraform backend   <-- ACTIVE
#   2. ingestion     → API Gateway, Kinesis Firehose
#   3. processing    → Collector Lambda, Transformer Lambda, DynamoDB
#   4. scheduler     → EventBridge Scheduler          <-- ACTIVE
#   5. analytics     → Glue Catalog, Athena
#   6. observability → CloudWatch, SNS alerts
#
#   Terraform Backend       → Need foundation stack locally created 
#                           → S3 bucket + DynamoDB table for Terraform state
# Modules not yet built are shown as commented-out blocks with
# their expected inputs documented for planning purposes.
# =============================================================


# -------------------------------------------------------------
# Stack 1: Foundation
# -------------------------------------------------------------
# Provisions the shared infrastructure that every other stack
# depends on: S3 data bucket, Terraform state bucket,
# DynamoDB lock table, KMS encryption key, and base IAM roles.
#
# Status: TODO — build next
# -------------------------------------------------------------
module "foundation" {
  source = "./modules/foundation"
  name_prefix = local.name_prefix
  aws_region  = var.aws_region
  tags        = local.common_tags
  environment   = var.environment
  raw_data_prefix = var.raw_data_prefix
  processed_data_prefix = var.processed_data_prefix
  athena_results_prefix = var.athena_results_prefix
  raw_data_expiry_days = var.raw_data_expiry_days
  processed_data_expiry_days = var.processed_data_expiry_days
  kms_key_deletion_window_days = var.kms_key_deletion_window_days
  enable_data_bucket_versioning = var.enable_data_bucket_versioning
  lambda_function_bucket = var.lambda_function_bucket
}

# --------------------------------------------------------------
# Remote State Backend for Terraform 
# --------------------------------------------------------------
#
# IMPORTANT — Bootstrap problem explained:
# The S3 bucket and DynamoDB table for storing Terraform state
# are created by the Foundation module (Foudation stack: 
# S3 for data lake, KMS for entire project, S3 for Terraform state, 
# DynamoDB for Terraform state locking).
# This means we cannot configure the backend BEFORE the Foundation
# stack exists. The correct workflow is:
#
# After migration, all state is stored remotely and team members
# can collaborate safely with state locking via DynamoDB.
#
# ---------------------------------------------------------------
# Uncomment the block below AFTER the Foundation stack is deployed:
# ---------------------------------------------------------------

# terraform {
#   backend "s3" {
#     bucket         = "terraform-states-897035677417"   # created by foundation module
#     key            = "earthquake-analytics/dev/terraform.tfstate"
#     region         = "eu-central-1"
#     dynamodb_table = "earthquake-analytics-dev-terraform-lock"    # created by foundation module
#     encrypt        = true
#   }
# }



# -------------------------------------------------------------
# Stack 2: Ingestion
# -------------------------------------------------------------
# API Gateway (REST) → Kinesis Data Firehose → S3
# The API Gateway exposes a POST /ingest endpoint.
# Firehose buffers records and calls the Transformer Lambda
# before writing to S3.
#
# Status: TODO
# Depends on: foundation (s3_bucket_id), processing (transformer_lambda_arn)
# -------------------------------------------------------------
# module "ingestion" {
#   source = "./modules/ingestion"
#
#   name_prefix            = local.name_prefix
#   s3_bucket_id           = module.foundation.data_bucket_id
#   s3_bucket_arn          = module.foundation.data_bucket_arn
#   transformer_lambda_arn = module.processing.transformer_lambda_arn
#   tags                   = local.common_tags
# }


# -------------------------------------------------------------
# Stack 3a: Collector Lambda                   ← ACTIVE
# -------------------------------------------------------------
# Deploys the collector Lambda function.
# The Lambda fetches the USGS earthquake feed and forwards events
# to the ingest endpoint (API Gateway, once Stack 2 is deployed).
# Deployment package (.zip) must be uploaded to S3 before apply:
#   ./pythonCode/collector/zip_python_lambda.sh src lambda_collector.zip
#   aws s3 cp lambda_collector.zip s3://<lambda_function_bucket>/<s3_key>
#
# Status: ACTIVE
# Depends on: foundation (lambda_function_bucket)
# -------------------------------------------------------------
module "collector_lambda" {
  source = "./modules/collector_lambda"

  lambda_function_name = "${local.name_prefix}-collector"
  lambda_s3_bucket     = var.lambda_function_bucket
  lambda_s3_key        = local.collector_lambda_s3_key
  lambda_handler       = var.collector_lambda_handler
  lambda_runtime       = var.collector_lambda_runtime
  lambda_memory_size   = var.collector_lambda_memory_size
  lambda_timeout       = var.collector_lambda_timeout
  tags                 = local.common_tags
  lambda_environment   = {
    USGS_FEED_URL          = var.usgs_feed_url
    USGS_FEED_TYPE         = var.usgs_feed_type
    COLLECTOR_DRY_RUN      = var.collector_dry_run
    # INGEST_API_URL is set once API Gateway (Stack 2) is deployed:
    # INGEST_API_URL       = module.ingestion.api_gateway_invoke_url
  }
}


# -------------------------------------------------------------
# Stack 3b: Processing (Full)
# -------------------------------------------------------------
# Collector Lambda: fetches USGS feed, posts events to API Gateway
# Transformer Lambda: enriches and normalises records for Firehose
# DynamoDB: deduplication table (tracks already-ingested event IDs)
#
# Status: TODO
# Depends on: foundation (s3_bucket_id), ingestion (api_gateway_invoke_url)
# -------------------------------------------------------------
# module "processing" {
#   source = "./modules/processing"
#
#   name_prefix         = local.name_prefix
#   s3_bucket_id        = module.foundation.data_bucket_id
#   api_gateway_url     = module.ingestion.api_gateway_invoke_url
#   api_gateway_key     = module.ingestion.api_gateway_key
#   usgs_feed_url       = var.usgs_feed_url
#   tags                = local.common_tags
# }


# -------------------------------------------------------------
# Stack 4: Scheduler                           ← ACTIVE
# -------------------------------------------------------------
# EventBridge Scheduler triggers the Collector Lambda every N minutes.
# The Collector Lambda polls the USGS GeoJSON feed for new events.
#
# Status: BUILT — see ./modules/scheduler/
# Depends on: processing (target_lambda_arn)
#
# NOTE: collector_lambda_arn_override is a temporary variable used
# while the processing module is not yet deployed. Once Stack 3
# is built, replace the target_lambda_arn line with:
#   target_lambda_arn = module.processing.collector_lambda_arn
# -------------------------------------------------------------
module "scheduler" {
  source = "./modules/scheduler"

  name_prefix         = local.name_prefix
  schedule_group_name = "${local.name_prefix}-schedule-group"
  schedule_name       = "${local.name_prefix}-usgs-collector"
  schedule_expression = var.collection_interval
  usgs_feed_url       = var.usgs_feed_url
  usgs_feed_type      = var.usgs_feed_type
  enabled             = true
  tags                = local.common_tags

  # Temporary override — replace with module.processing.collector_lambda_arn
  # once Stack 3 (processing) is deployed.
  target_lambda_arn = module.collector_lambda.lambda_function_arn

  # Dead-letter queue wired in once observability module (Stack 6) is built:
  # dead_letter_queue_arn = module.observability.scheduler_dlq_arn
  dead_letter_queue_arn = null
}


# -------------------------------------------------------------
# Stack 5: Analytics
# -------------------------------------------------------------
# Glue Database + Glue Crawler → Athena Workgroup
# Makes S3 data queryable via standard SQL.
#
# Status: TODO
# Depends on: foundation (s3_bucket_id, s3_bucket_arn)
# -------------------------------------------------------------
# module "analytics" {
#   source = "./modules/analytics"
#
#   name_prefix          = local.name_prefix
#   s3_bucket_id         = module.foundation.data_bucket_id
#   s3_bucket_arn        = module.foundation.data_bucket_arn
#   athena_results_prefix = "athena-results/"
#   tags                 = local.common_tags
# }


# -------------------------------------------------------------
# Stack 6: Observability
# -------------------------------------------------------------
# CloudWatch log groups, metric alarms, SNS email alerts,
# SQS dead-letter queue for the scheduler.
#
# Status: TODO
# Depends on: processing (lambda names for metric filters)
# -------------------------------------------------------------
# module "observability" {
#   source = "./modules/observability"
#
#   name_prefix               = local.name_prefix
#   collector_lambda_name     = module.processing.collector_lambda_name
#   transformer_lambda_name   = module.processing.transformer_lambda_name
#   alert_email               = var.alert_email
#   tags                      = local.common_tags
# }
