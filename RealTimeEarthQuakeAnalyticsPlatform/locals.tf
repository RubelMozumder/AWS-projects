# =============================================================
# Local Values
# =============================================================
# Locals are computed once and reused across all module calls.
# They prevent repetition and ensure naming consistency.

locals {
  # Standard prefix for every resource name: "<project>-<env>"
  # Example: "eq-analytics-dev"
  name_prefix = "${var.project_name}-${var.environment}"
  collector_lambda_s3_key = "${var.project_name}/collector/lambda_collector.zip"

  # Common tags applied to every resource via each module's tags input.
  # The provider-level `default_tags` already covers Project/Environment/ManagedBy,
  # but passing them here too makes modules self-documenting.
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
