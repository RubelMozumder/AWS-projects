# =============================================================
# Module: scheduler — Input Variables
# =============================================================

# ---- Naming -------------------------------------------------

# ---- Project variables --------------------------------------

variable "project_name" {
  description = "Project name applied to every resource name. Typically '<project>-<environment>' (e.g. 'eq-analytics-dev')."
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g. dev, staging, prod). Used in resource naming and tagging."
  type        = string
}

# ------ Event Scheduler variables ----------------------------

variable "schedule_group_name" {
  description = "Name for the EventBridge Scheduler schedule group."
  type        = string
}

variable "schedule_name" {
  description = "Name for the EventBridge schedule resource."
  type        = string
}

# ---- Schedule -----------------------------------------------

variable "schedule_expression" {
  description = <<-EOT
    When the schedule fires. Supports two formats:

    rate expression → rate(<value> <unit>)
      Examples:
        rate(5 minutes)   fires every 5 minutes
        rate(1 hour)      fires every hour
        rate(1 day)       fires once per day

    cron expression → cron(<min> <hour> <day> <month> <weekday> <year>)
      Examples:
        cron(*/5 * * * ? *)   every 5 minutes
        cron(0 * * * ? *)     top of every hour
        cron(0 6 * * ? *)     06:00 UTC daily

    Note: EventBridge cron uses ? for "any" in day-of-month or
    day-of-week (not * like standard Unix cron).
  EOT
  type        = string
  default     = "rate(5 minutes)"

  validation {
    condition     = can(regex("^(rate|cron)\\(.+\\)$", var.schedule_expression))
    error_message = "schedule_expression must start with 'rate(' or 'cron(' and end with ')'."
  }
}

variable "enabled" {
  description = <<- EOT
    Controls schedule state. true = ENABLED (actively firing). false = DISABLED
    (paused, useful during development or debugging).
  EOT
  type        = bool
  default     = true
}

# ---- Target Lambda ------------------------------------------

variable "target_lambda_arn" {
  description = <<-EOT
    ARN of the Collector Lambda function that the scheduler invokes.
    Provided by the processing module once built:
      module.processing.collector_lambda_arn
    During development, set via collector_lambda_arn_override in terraform.tfvars.
  EOT
  type        = string

  validation {
    condition     = can(regex("^arn:aws:lambda:[a-z0-9-]+:[0-9]{12}:function:.+$", var.target_lambda_arn))
    error_message = "target_lambda_arn must be a valid Lambda function ARN (arn:aws:lambda:<region>:<account>:function:<name>)."
  }
}

# ---- USGS Feed ----------------------------------------------

variable "usgs_feed_url" {
  description = <<- EOT
    Full URL of the USGS GeoJSON earthquake feed. 
    Passed to the Collector Lambda as the event payload's feed_url field.
  EOT
  type        = string
  default     = "https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/all_hour.geojson"
}

variable "usgs_feed_type" {
  description = <<-EOT
    Short identifier for the USGS feed type. Passed in the Lambda event
    payload as feed_type. Used for logging and S3 partitioning.
    Valid values mirror the USGS feed catalogue:
      all_hour         → all events, last 60 minutes (most current)
      all_day          → all events, last 24 hours
      all_week         → all events, last 7 days
      all_month        → all events, last 30 days
      significant_week → significant events only, last 7 days
      significant_month→ significant events only, last 30 days
  EOT
  type        = string
  default     = "all_hour"

  validation {
    condition = contains([
      "all_hour",
      "all_day",
      "all_week",
      "all_month",
      "significant_week",
      "significant_month"
    ], var.usgs_feed_type)
    error_message = "usgs_feed_type must be one of: all_hour, all_day, all_week, all_month, significant_week, significant_month."
  }
}

# ---- Dead-Letter Queue (optional) ---------------------------

variable "dead_letter_queue_arn" {
  description = <<-EOT
    ARN of an SQS queue to receive events that the scheduler
    failed to deliver after all retries. Optional.
    Will be provided by the observability module (Stack 6):
      module.observability.scheduler_dlq_arn
    Set to null to disable dead-letter handling during development.
  EOT
  type        = string
  default     = null
}

# ---- Tags ---------------------------------------------------

variable "tags" {
  description = "Map of tags applied to all resources in this module."
  type        = map(string)
  default     = {}
}
