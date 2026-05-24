# =============================================================
# Module: scheduler — Outputs
# =============================================================
# These values are consumed by the root module (main.tf outputs.tf)
# and potentially by the observability module for metric filtering.

output "schedule_arn" {
  description = "ARN of the EventBridge schedule. Use this to reference the schedule in CloudWatch alarms or IAM policies."
  value       = aws_scheduler_schedule.usgs_collector.arn
}

output "schedule_name" {
  description = "Name of the EventBridge schedule."
  value       = aws_scheduler_schedule.usgs_collector.name
}

output "schedule_group_arn" {
  description = "ARN of the EventBridge schedule group."
  value       = aws_scheduler_schedule_group.this.arn
}

output "schedule_group_name" {
  description = "Name of the EventBridge schedule group."
  value       = aws_scheduler_schedule_group.this.name
}

output "scheduler_role_arn" {
  description = "ARN of the IAM role assumed by EventBridge Scheduler to invoke the Collector Lambda."
  value       = aws_iam_role.scheduler.arn
}

output "scheduler_role_name" {
  description = "Name of the IAM role. Useful for attaching additional policies in later modules."
  value       = aws_iam_role.scheduler.name
}
