# =============================================================
# Module: ingestion — Input Variables
# =============================================================

variable "name_prefix" {
  description = "Prefix for all resource names (e.g. eq-analytics-dev)"
  type        = string
}

variable "s3_bucket_arn" {
  description = "ARN of the S3 data lake bucket (from foundation module). Used in IAM policies and Firehose destination config."
  type        = string
}

variable "kms_key_arn" {
  description = "ARN of the KMS CMK (from foundation module). Firehose role needs this to encrypt objects written to S3."
  type        = string
}

variable "raw_data_prefix" {
  description = <<-EOT
    S3 key prefix for raw records delivered by Firehose (e.g. raw/).
    Firehose appends Hive-style date partitions after this prefix:
      raw/year=2025/month=05/day=23/hour=14/
  EOT
  type        = string
  default     = "raw/"
}

# ---- Firehose buffering --------------------------------------
# Firehose flushes to S3 when EITHER threshold is reached first.
# Lower values = more frequent (smaller) S3 files, fresher data.
# Higher values = fewer (larger) files, slightly lower cost.

variable "firehose_buffer_size_mb" {
  description = "Firehose buffer size in MB before flushing to S3. Range: 1–128."
  type        = number
  default     = 5

  validation {
    condition     = var.firehose_buffer_size_mb >= 1 && var.firehose_buffer_size_mb <= 128
    error_message = "firehose_buffer_size_mb must be between 1 and 128."
  }
}

variable "firehose_buffer_interval_seconds" {
  description = "Firehose buffer interval in seconds before flushing to S3. Range: 60–900."
  type        = number
  default     = 60

  validation {
    condition     = var.firehose_buffer_interval_seconds >= 60 && var.firehose_buffer_interval_seconds <= 900
    error_message = "firehose_buffer_interval_seconds must be between 60 and 900."
  }
}

# ---- API Gateway ---------------------------------------------

variable "stage_name" {
  description = "API Gateway deployment stage name (e.g. v1, dev, prod)"
  type        = string
  default     = "v1"
}

variable "api_rate_limit_rps" {
  description = <<-EOT
    Steady-state request rate limit for the usage plan (requests per second).
    The collector Lambda triggers every 5 minutes and posts ~10–200 records per
    invocation — 10 rps is generous but prevents runaway costs if misconfigured.
  EOT
  type        = number
  default     = 10
}

variable "api_burst_limit" {
  description = "Maximum concurrent requests allowed by the usage plan before throttling."
  type        = number
  default     = 20
}

variable "tags" {
  description = "Tags applied to all resources in this module."
  type        = map(string)
  default     = {}
}
