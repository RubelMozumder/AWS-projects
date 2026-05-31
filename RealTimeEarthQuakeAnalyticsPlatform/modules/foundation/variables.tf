# =============================================================
# Module: foundation — Input Variables
# =============================================================

# ---- Naming -------------------------------------------------

variable "name_prefix" {
  description = "Prefix applied to every resource name. Typically '<project>-<environment>' (e.g. 'eq-analytics-dev')."
  type        = string
}

variable "aws_region" {
  description = "AWS region. Passed into the KMS key policy to scope permissions to this region."
  type        = string
}

# ---- S3 Data Lake -------------------------------------------

variable "raw_data_prefix" {
  description = <<-EOT
    S3 key prefix for raw earthquake records exactly as received
    from the USGS feed — before any transformation.
    Example path: raw/year=2025/month=05/day=23/hour=14/record.json.gz
  EOT
  type    = string
}

variable "processed_data_prefix" {
  description = <<-EOT
    S3 key prefix for enriched, normalised records written by
    the Transformer Lambda in Parquet format.
    Example path: processed/year=2025/month=05/day=23/record.parquet
  EOT
  type    = string
}

variable "athena_results_prefix" {
  description = <<-EOT
    S3 key prefix where Athena stores query result files (.csv).
    Athena requires a dedicated output location per workgroup.
    Example path: athena-results/abc123.csv
  EOT
  type    = string
}

variable "raw_data_expiry_days" {
  description = <<-EOT
    Number of days before raw data objects are permanently deleted.
    Raw data is large (uncompressed JSON) and only needed for reprocessing.
    90 days covers any realistic reprocessing window.
  EOT
  type    = number

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

  validation {
    condition     = var.processed_data_expiry_days >= 90
    error_message = "processed_data_expiry_days must be at least 90 days."
  }
}

variable "environment" {
  description = <<-EOT
    Deployment environment (e.g. "dev", "staging", "prod").
    Used to gate destructive settings — e.g. force_destroy is
    disabled automatically when environment is "prod".
  EOT
  type = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "enable_data_bucket_versioning" {
  description = <<-EOT
    Whether to enable S3 versioning on the data lake bucket.
    Versioning protects against accidental deletes and enables
    point-in-time recovery of any object.
    Recommended: true for production, can be false for dev to save cost.
  EOT
  type    = bool
}

# ---- KMS ----------------------------------------------------

variable "kms_key_deletion_window_days" {
  description = <<-EOT
    Waiting period (in days) before a scheduled KMS key deletion
    takes effect. AWS minimum is 7 days, maximum is 30 days.
    During this window the deletion can be cancelled.
    Use 7 in dev (faster teardown), 30 in prod (safety net).
  EOT
  type    = number

  validation {
    condition     = var.kms_key_deletion_window_days >= 7 && var.kms_key_deletion_window_days <= 30
    error_message = "kms_key_deletion_window_days must be between 7 and 30."
  }
}

# ---- Tags ---------------------------------------------------

variable "tags" {
  description = "Map of tags applied to all resources in this module."
  type        = map(string)
  default     = {}
}

variable "lambda_function_bucket" {
  description = "S3 bucket name for storing Lambda deployment packages."
  type        = string
  default     = "lambda-code-897035677417"
}
