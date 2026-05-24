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
