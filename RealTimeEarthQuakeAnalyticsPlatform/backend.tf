# =============================================================
# Remote State Backend
# =============================================================
#
# IMPORTANT — Bootstrap problem explained:
# The S3 bucket and DynamoDB table for storing Terraform state
# are created by the Foundation module (Stack 1: foundation stack).
# This means we cannot configure the backend BEFORE the Foundation
# stack exists. The correct workflow is:
#
#   Step 1: Use local state (default — nothing to configure)
#   Step 2: Deploy Foundation module  →  S3 bucket + DynamoDB table created
#   Step 3: Uncomment the backend block below
#   Step 4: Run `terraform init -migrate-state`
#           Terraform will copy local state into S3 automatically
#
# After migration, all state is stored remotely and team members
# can collaborate safely with state locking via DynamoDB.
#
# ---------------------------------------------------------------
# Uncomment the block below AFTER the Foundation stack is deployed:
# ---------------------------------------------------------------

terraform {
  backend "s3" {
    bucket         = "terraform-states-897035677417"   # created by foundation module
    key            = "eq-analytics/dev/terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "eq-analytics-dev-tf-lock"    # created by foundation module
    use_lockfile   = true
    encrypt        = true
  }
}
