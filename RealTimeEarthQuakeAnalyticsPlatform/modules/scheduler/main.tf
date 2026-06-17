# =============================================================
# Module: scheduler
# =============================================================
# Provisions an Amazon EventBridge Scheduler that fires on a
# configurable interval and invokes the Collector Lambda function.
#
# Resources created:
#   - aws_scheduler_schedule_group   (logical container)
#   - aws_scheduler_schedule         (the schedule itself)
#   - aws_iam_role                   (allows scheduler to invoke Lambda)
#   - aws_iam_role_policy            (grants lambda:InvokeFunction)
#
# Inputs required:
#   - name_prefix        → used to name every resource
#   - target_lambda_arn  → the Collector Lambda to invoke
#
# How it connects to the rest of the pipeline:
#
#   EventBridge Scheduler
#         │  fires every N minutes
#         ▼
#   Collector Lambda  (module: processing)
#         │  fetches USGS GeoJSON, posts each event to:
#         ▼
#   API Gateway       (module: ingestion)
# =============================================================


# -------------------------------------------------------------
# Data Sources
# -------------------------------------------------------------

# Retrieve the current AWS account ID.
# Used in the IAM trust policy Condition to scope the trust
# strictly to this account — a security best practice.
data "aws_caller_identity" "current" {}


# -------------------------------------------------------------
# Schedule Group
# -------------------------------------------------------------
# A schedule group is a logical container for one or more schedules.
# Benefits:
#   - Organise all project schedules under one namespace
#   - Apply tags at the group level
#   - Delete all schedules in a group in one API call
#
# All schedules for this project live in this single group.

resource "aws_scheduler_schedule_group" "this" {
  name = var.schedule_group_name

  tags = var.tags
}


# -------------------------------------------------------------
# IAM Role — EventBridge Scheduler → Lambda
# -------------------------------------------------------------
# EventBridge Scheduler assumes this role when it fires.
# The role grants only the minimum permissions needed:
# invoking the specific Collector Lambda function.
#
# Why a dedicated role (not a shared role)?
#   Least-privilege principle: this role can ONLY invoke this
#   one Lambda. If the scheduler is compromised, blast radius
#   is limited to triggering the collector — nothing else.

resource "aws_iam_role" "scheduler" {
  name        = "${var.name_prefix}-scheduler-role"
  description = "Allows EventBridge Scheduler to invoke the USGS Collector Lambda"

  # Trust policy: only the EventBridge Scheduler service can assume this role,
  # and only within this AWS account (Condition prevents cross-account abuse).
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowSchedulerAssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "scheduler.amazonaws.com"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })

  tags = var.tags
}


# -------------------------------------------------------------
# IAM Policy — Grant Lambda Invoke Permission
# -------------------------------------------------------------
# Attached to the scheduler role above.
# Allows invocation of both the function itself and any
# published versions/aliases (e.g. function:prod alias).

resource "aws_iam_role_policy" "scheduler_invoke_lambda" {
  name = "${var.name_prefix}-scheduler-invoke-lambda"
  role = aws_iam_role.scheduler.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCollectorLambdaInvoke"
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = [
          var.target_lambda_arn,
          "${var.target_lambda_arn}:*" # covers version/alias ARNs
        ]
      }
    ]
  })
}


# -------------------------------------------------------------
# EventBridge Schedule
# -------------------------------------------------------------
# The schedule fires on the configured interval and delivers
# an input payload directly to the target Lambda function.
#
# Key design decisions:
#
# flexible_time_window = OFF
#   The Lambda must fire at exactly the scheduled time, not within
#   a window. Because we poll a live data feed, precision matters —
#   a delayed fetch could miss events from the previous window.
#
# retry_policy
#   If the Lambda invocation fails (e.g. cold-start timeout),
#   retry up to 2 times within 5 minutes. After that, the event
#   is dropped (or sent to the DLQ if configured).
#
# dead_letter_config (optional)
#   If a DLQ ARN is provided, failed events land in SQS for
#   debugging. Wired from the observability module in Stack 6.
#
# input payload
#   Passed verbatim to the Lambda event object. The Collector
#   Lambda reads feed_url to know which USGS endpoint to fetch.

resource "aws_scheduler_schedule" "usgs_collector" {
  name        = var.schedule_name
  group_name  = aws_scheduler_schedule_group.this.name
  description = "Polls USGS earthquake feed (${var.usgs_feed_type}) and invokes the Collector Lambda"

  # Fire at exactly the scheduled time — no flexibility window
  flexible_time_window {
    mode = "OFF"
  }

  schedule_expression          = var.schedule_expression
  schedule_expression_timezone = "UTC"

  # ENABLED = actively firing | DISABLED = paused (useful for debugging)
  state = var.enabled ? "ENABLED" : "DISABLED"

  target {
    arn      = var.target_lambda_arn
    role_arn = aws_iam_role.scheduler.arn

    # JSON payload delivered to the Lambda handler as the event object.
    # Lambda reads these fields to determine which feed URL to fetch
    # and to tag the resulting records with their source metadata.
    input = jsonencode({
      source    = "eventbridge-scheduler"
      feed_url  = var.usgs_feed_url
      feed_type = var.usgs_feed_type
    })

    retry_policy {
      maximum_retry_attempts       = 2   # retry twice on failure
      maximum_event_age_in_seconds = 300 # discard if older than 5 minutes
    }

    # Dead-letter queue: only created if a DLQ ARN is provided.
    # Uses a dynamic block so the attribute is omitted entirely when null.
    dynamic "dead_letter_config" {
      for_each = var.dead_letter_queue_arn != null ? [var.dead_letter_queue_arn] : []
      content {
        arn = dead_letter_config.value
      }
    }
  }
}
