# =============================================================
# Root Module — Input Variables
# =============================================================

# ---- General ------------------------------------------------

variable "aws_region" {
  description = "AWS region where all resources will be deployed"
  type        = string
  default     = "eu-central-1"
}

variable "project_name" {
  description = "Short project name used as prefix for all resource names (lowercase, no spaces)"
  type        = string
  default     = "eq-analytics"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,20}$", var.project_name))
    error_message = "project_name must be lowercase, 3–20 characters, letters/numbers/hyphens only."
  }
}

variable "environment" {
  description = "Deployment environment label"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

# ---- S3 Prefixes and Data Lifecycle --------------------------------------------

variable "raw_data_prefix" {
  description = <<-EOT
    S3 key prefix for raw earthquake records exactly as received
    from the USGS feed — before any transformation.
    Example path: raw/year=2025/month=05/day=23/hour=14/record.json.gz
  EOT
  type    = string
  default = "raw/"
}

variable "processed_data_prefix" {
  description = <<-EOT
    S3 key prefix for enriched, normalised records written by
    the Transformer Lambda in Parquet format.
    Example path: processed/year=2025/month=05/day=23/record.parquet
  EOT
  type    = string
  default = "processed/"
}

variable "athena_results_prefix" {
  description = <<-EOT
    S3 key prefix where Athena stores query result files (.csv).
    Athena requires a dedicated output location per workgroup.
    Example path: athena-results/abc123.csv
  EOT
  type    = string
  default = "athena-results/"
}

variable "raw_data_expiry_days" {
  description = <<-EOT
    Number of days before raw data objects are permanently deleted.
    Raw data is large (uncompressed JSON) and only needed for reprocessing.
    180 days covers any realistic reprocessing window.
  EOT
  type    = number
  default = 180

  validation {
    condition     = var.raw_data_expiry_days >= 30
    error_message = "raw_data_expiry_days must be at least 30 days."
  }
}

variable "processed_data_expiry_days" {
  description = <<-EOT
    Number of days before processed Parquet data is permanently deleted.
    Processed data is compact and directly queried by Athena —
    keep it longer than raw data.
  EOT
  type    = number
  default = 365

  validation {
    condition     = var.processed_data_expiry_days >= 90
    error_message = "processed_data_expiry_days must be at least 90 days."
  }
}

variable "kms_key_deletion_window_days" {
  description = <<-EOT
    Number of days before a scheduled KMS key deletion is executed.
    AWS enforces a minimum of 7 days and a maximum of 30 days.
    This is a safety buffer to prevent accidental key deletions.
  EOT
  type    = number
  default = 14

  validation {
    condition     = var.kms_key_deletion_window_days >= 7 && var.kms_key_deletion_window_days <= 30
    error_message = "kms_key_deletion_window_days must be between 7 and 30 days."
  }
}

variable "enable_data_bucket_versioning" {
  description = <<-EOT
    Whether to enable S3 versioning on the data lake bucket.
    Versioning provides protection against accidental deletions and overwrites,
    but may increase storage costs. Recommended for all environments, including prod.
  EOT
  type    = bool
  default = true
}

# ---- Scheduler ----------------------------------------------

variable "collection_interval" {
  description = <<-EOT
    How often the EventBridge Scheduler triggers the Collector Lambda.
    Supports rate() or cron() expressions.
    Examples:
      rate(5 minutes)   → every 5 minutes
      rate(1 hour)      → every hour
      cron(0 * * * ? *) → top of every hour
  EOT
  type        = string
  default     = "rate(5 minutes)"
}

variable "usgs_feed_url" {
  description = "Full USGS GeoJSON earthquake feed URL"
  type        = string
  default     = "https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/all_hour.geojson"
}

variable "usgs_feed_type" {
  description = "USGS feed type identifier, passed to the Lambda in the event payload"
  type        = string
  default     = "all_hour"
}

# ---- Collector Lambda ---------------------------------------

variable "lambda_function_bucket" {
  description = "S3 bucket name where Lambda deployment packages are stored"
  type        = string
  default     = "lambda-code-897035677417"
  
}

variable "collector_lambda_handler" {
  description = "Lambda handler in the format <module>.<function>"
  type        = string
  default     = "lambda_collector.lambda_handler"
}

variable "collector_lambda_runtime" {
  description = "Python runtime for the collector Lambda"
  type        = string
  default     = "python3.12"
}

variable "collector_lambda_memory_size" {
  description = "Memory size in MB for the collector Lambda"
  type        = number
  default     = 256
}

variable "collector_lambda_timeout" {
  description = "Timeout in seconds for the collector Lambda"
  type        = number
  default     = 30
}

variable "collector_dry_run" {
  description = "When true, the collector Lambda fetches events but does not POST to the ingest endpoint"
  type        = bool
  default     = false
}

# ---- Development override -----------------------------------
# Used during development before the processing module (Stack 3)
# is built. Replace with module.processing.collector_lambda_arn
# once the processing module exists.

variable "collector_lambda_arn_override" {
  description = <<-EOT
    Temporary override for the Collector Lambda ARN.
    Used while the processing module is not yet deployed.
    Once Stack 3 (processing) is built, remove this variable
    and wire: target_lambda_arn = module.processing.collector_lambda_arn
  EOT
  type        = string
  default     = null
}
