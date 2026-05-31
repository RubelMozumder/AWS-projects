# =============================================================
# Module: foundation
# =============================================================
# Provisions the shared infrastructure that every other stack
# depends on. Must be deployed first.
#
# Resources created:
#   KMS
#     - aws_kms_key              → customer-managed encryption key
#     - aws_kms_alias            → human-readable key alias
#
#   S3 — Data Lake
#     - aws_s3_bucket                              → main data bucket
#     - aws_s3_bucket_versioning                   → object versioning
#     - aws_s3_bucket_server_side_encryption_configuration → KMS encryption
#     - aws_s3_bucket_public_access_block          → block all public access
#     - aws_s3_bucket_lifecycle_configuration      → expiry rules per prefix
#
#   S3 — Terraform State
#     - aws_s3_bucket                              → state storage bucket
#     - aws_s3_bucket_versioning                   → required: every state version kept
#     - aws_s3_bucket_server_side_encryption_configuration → KMS encryption
#     - aws_s3_bucket_public_access_block          → block all public access
#
#   DynamoDB — Terraform State Locking
#     - aws_dynamodb_table → prevents concurrent terraform operations
#
# How naming ensures global S3 uniqueness:
#   S3 bucket names must be globally unique across ALL AWS accounts.
#   We suffix every bucket name with the AWS account ID (12 digits),
#   which is unique per account. This guarantees no naming collision.
#   Example: "eq-analytics-dev-data-lake-123456789012"
# =============================================================


# -------------------------------------------------------------
# Data Sources
# -------------------------------------------------------------

# Retrieves the current AWS account ID and caller identity.
# Used to:
#   1. Suffix S3 bucket names for global uniqueness
#   2. Scope KMS key policy to this account only
data "aws_caller_identity" "current" {}


# -------------------------------------------------------------
# KMS Customer-Managed Key (CMK)
# -------------------------------------------------------------
# Why a Customer-Managed Key instead of the AWS-managed default?
#
#   AWS-managed key (aws/s3):
#     - Free
#     - No control over key policy
#     - Cannot grant cross-account access
#     - Cannot be used by other services (e.g. Firehose, Glue)
#       without extra configuration
#
#   Customer-managed key (our choice):
#     - $1/month per key + $0.03 per 10,000 API calls (negligible)
#     - Full control over who can use, administer, and delete the key
#     - One key shared across S3, Firehose, and Glue — consistent encryption
#     - Automatic key rotation (enabled below) for compliance
#     - Can be audited via CloudTrail (every encrypt/decrypt logged)
#
# Key policy explained:
#   Statement 1 — AllowRootFullControl
#     The root account has full key administration rights.
#     Without this, if all other admins are deleted, the key
#     becomes permanently inaccessible (unrecoverable).
#
#   Statement 2 — AllowIAMUsersDelegation
#     Allows IAM policies to control key usage. This means we can
#     grant Lambda, Firehose, and Glue access via their IAM roles
#     without editing the key policy each time.
#
#   Statement 3 — AllowS3ServiceUsage
#     S3 needs to call KMS on behalf of the bucket to encrypt/decrypt
#     objects. The kms:ViaService condition ensures the key can only
#     be used when the request originates from S3 — not directly.
#
#   Statement 4 — AllowFirehoseServiceUsage
#     Kinesis Firehose needs KMS access to encrypt data before
#     writing it to S3. Added now so Firehose works when Stack 2
#     (ingestion) is deployed without touching this key policy again.

resource "aws_kms_key" "main" {
  description             = <<-EOF
    CMK for ${var.name_prefix} — encrypts S3 data lake, 
    Terraform state, and Firehose delivery
  EOF
  deletion_window_in_days = var.kms_key_deletion_window_days

  # Automatic key rotation: AWS generates new key material every year.
  # Old versions are retained so existing data can still be decrypted.
  # This is a security and compliance best practice — no manual rotation needed.
  enable_key_rotation = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowRootFullControl"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowIAMUsersDelegation"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowS3ServiceUsage"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:ViaService"    = "s3.${var.aws_region}.amazonaws.com"
            "kms:CallerAccount" = data.aws_caller_identity.current.account_id
          }
        }
      },
      {
        Sid    = "AllowFirehoseServiceUsage"
        Effect = "Allow"
        Principal = {
          Service = "firehose.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:ViaService"    = "firehose.${var.aws_region}.amazonaws.com"
            "kms:CallerAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })

  # IMPORTANT: Prevent accidental deletion during terraform destroy.
  # This key encrypts S3 data and Terraform state.
  # To enable destroy after intentionally removing this protection:
  #   1. Remove or set to 'false': lifecycle { prevent_destroy = true }
  #   2. Run: terraform apply
  #   3. Then destroy can proceed.
  lifecycle {
    prevent_destroy = true
  }

  tags = var.tags
}

# Human-readable alias for the KMS key.
# Instead of referencing the key by its ID (a UUID),
# other resources and the AWS console show "alias/eq-analytics-dev-main".
resource "aws_kms_alias" "main" {
  name          = "alias/${var.name_prefix}-main"
  target_key_id = aws_kms_key.main.key_id
}


# =============================================================
# S3 — Data Lake Bucket
# =============================================================
# Stores all earthquake data in two prefixes:
#   raw/        → original GeoJSON records from USGS (compressed JSON)
#   processed/  → enriched, flattened Parquet records (queryable by Athena)
#   athena-results/ → Athena query output files (.csv)
#
# Why separate prefixes instead of separate buckets?
#   - Simpler IAM: one bucket ARN covers all data
#   - Simpler lifecycle rules: per-prefix expiry in one place
#   - Lower cost: one bucket = one set of request charges
#   - Athena, Glue, and Firehose all work with prefix-level paths
# =============================================================

resource "aws_s3_bucket" "data_lake" {
  # Account ID suffix guarantees global uniqueness.
  bucket = "${var.name_prefix}-data-lake-${data.aws_caller_identity.current.account_id}"

  # force_destroy: when true, `terraform destroy` empties the bucket
  # automatically before deleting it. Safe for dev — in prod set to false
  # so an accidental destroy never silently wipes data.
  force_destroy = false
  # force_destroy = var.environment != "prod"

  # CRITICAL: Prevent accidental deletion of the data lake.
  # This bucket contains earthquake data that is the foundation of the platform.
  # Even if force_destroy=false, we also add prevent_destroy for extra protection.
  # To enable destroy after intentionally removing this protection:
  #   1. Remove or set to 'false': lifecycle { prevent_destroy = true }
  #   2. Run: terraform apply
  #   3. Then destroy can proceed (if force_destroy=false, bucket must be empty first).
  lifecycle {
    prevent_destroy = true
  }

  tags = var.tags
}

# Versioning: keeps every version of every object.
# Benefits:
#   - Accidental overwrite? Previous version still exists.
#   - Corrupted Parquet file? Roll back to last good version.
#   - Required by Firehose: Firehose uses versioning internally
#     to guarantee exactly-once delivery semantics.
resource "aws_s3_bucket_versioning" "data_lake" {
  bucket = aws_s3_bucket.data_lake.id

  versioning_configuration {
    status = var.enable_data_bucket_versioning ? "Enabled" : "Suspended"
  }
}

# Server-side encryption: every object written to this bucket is
# automatically encrypted at rest using the KMS CMK above.
# Encryption is transparent to readers — IAM controls who can decrypt.
resource "aws_s3_bucket_server_side_encryption_configuration" "data_lake" {
  bucket = aws_s3_bucket.data_lake.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.main.arn
    }
    # bucket_key_enabled: reduces KMS API call costs by ~99%
    # by caching the data key at the bucket level instead of
    # calling KMS for every single object write.
    bucket_key_enabled = true
  }
}

# Public access block: four settings, all enabled.
# This is belt-and-suspenders protection:
#   - block_public_acls       → reject any PUT with a public ACL
#   - ignore_public_acls      → ignore any existing public ACLs
#   - block_public_policy     → reject any bucket policy granting public access
#   - restrict_public_buckets → restrict access even if policy accidentally allows it
# Earthquake data is private analytical data — it must never be publicly accessible.
resource "aws_s3_bucket_public_access_block" "data_lake" {
  bucket                  = aws_s3_bucket.data_lake.id
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

# Lifecycle rules: automatically manage object expiry per prefix.
# Without lifecycle rules, S3 storage grows forever and costs accumulate.
#
# Rule 1 — raw/ prefix
#   Raw JSON records are large and uncompressed. We only keep them
#   for reprocessing purposes. After 180 days they are deleted.
#   If the Transformer Lambda ever has a bug, 90 days is enough time
#   to reprocess from raw data.
#
# Rule 2 — processed/ prefix
#   Parquet records are compact and queried by Athena. Keep for 1 year
#   (365 days) as analytical history.
#
# Rule 3 — athena-results/ prefix
#   Athena query results are temporary CSV files. No value after 7 days.
#   Short expiry keeps the bucket clean and costs near zero.
resource "aws_s3_bucket_lifecycle_configuration" "data_lake" {
  bucket = aws_s3_bucket.data_lake.id

  # Lifecycle rules only apply to current object versions.
  # Versioning means non-current versions also accumulate.
  # These noncurrent_version_expiration blocks clean up old versions.

  rule {
    id     = "expire-raw-data"
    status = "Enabled"

    filter {
      prefix = var.raw_data_prefix
    }

    expiration {
      days = var.raw_data_expiry_days
    }

    noncurrent_version_expiration {
      noncurrent_days = 60 # clean up old versions after 60 days
    }
  }

  rule {
    id     = "expire-processed-data"
    status = "Enabled"

    filter {
      prefix = var.processed_data_prefix
    }

    expiration {
      days = var.processed_data_expiry_days
    }

    noncurrent_version_expiration {
      noncurrent_days = 60
    }
  }

  rule {
    id     = "expire-athena-results"
    status = "Enabled"

    filter {
      prefix = var.athena_results_prefix
    }

    expiration {
      days = 7
    }

    noncurrent_version_expiration {
      noncurrent_days = 3
    }
  }
}

# =============================================================
# Lambda Code bucket
# =============================================================
# Stores Lambda deployment packages (zip files) for all stacks.
# This bucket is shared across stacks to simplify deployment and avoid
# cross-stack dependencies.
# =============================================================

data "aws_s3_bucket" "lambda_code" {
  bucket = var.lambda_function_bucket
}

# =============================================================
# S3 — Terraform State Bucket
# =============================================================
# Stores the Terraform state file remotely so that:
#   - State is shared across team members and CI/CD pipelines
#   - State is not lost if a local machine is wiped
#   - Versioning allows rollback to any previous state version
#
# Why a separate bucket from the data lake?
#   - Different access control: only Terraform needs this bucket
#   - Different lifecycle: state files are never auto-deleted
#   - Separation of concerns: infrastructure state vs. pipeline data
#   - force_destroy = false: a mistaken terraform destroy must not
#     silently delete all infrastructure history
# =============================================================

resource "aws_s3_bucket" "terraform_state" {
  bucket        = "terraform-states-${data.aws_caller_identity.current.account_id}"
  # force_destroy = false # never auto-delete state — protect against accidents

  tags = var.tags
  # lifecycle {
  #   prevent_destroy = true
  # }
}

# Versioning is REQUIRED for Terraform remote state.
# Every `terraform apply` writes a new state file version.
# If a bad apply corrupts state, you can restore the previous version
# directly from the S3 console or AWS CLI.
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled" # always enabled — non-negotiable for state buckets
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.main.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket                  = aws_s3_bucket.terraform_state.id
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}


# =============================================================
# DynamoDB — Terraform State Lock Table
# =============================================================
# Prevents two Terraform operations from running simultaneously
# against the same state file — which would cause corruption.
#
# How state locking works:
#   1. `terraform apply` writes a lock record to DynamoDB (LockID = state file path)
#   2. Any other `terraform apply` attempt reads the table, sees the lock, and exits
#   3. When the first apply finishes, it deletes the lock record
#   4. The next apply can now acquire the lock and proceed
#
# Why DynamoDB for locking?
#   - S3 itself has no native locking mechanism
#   - DynamoDB conditional writes provide atomic lock acquisition
#   - The Terraform S3 backend has built-in DynamoDB locking support
#
# Schema:
#   Only one attribute is needed: LockID (String) — the partition key.
#   Terraform writes the S3 key of the state file as the LockID value.
#   Example: "earthquake-analytics/terraform.tfstate-md5"
#
# Billing:
#   PAY_PER_REQUEST — lock operations are infrequent (one per apply).
#   This costs fractions of a cent per month — far cheaper than
#   provisioned capacity (which has a minimum cost even when idle).
# =============================================================

resource "aws_dynamodb_table" "terraform_lock" {
  name         = "${var.name_prefix}-tf-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S" # S = String
  }

  # Point-in-time recovery: DynamoDB retains 35 days of change history.
  # If the lock table is accidentally corrupted, it can be restored
  # to any point within the last 35 days.
  point_in_time_recovery {
    enabled = true
  }

  # CRITICAL: Prevent accidental deletion of the lock table.
  # Without this table, Terraform state locking breaks, allowing concurrent
  # apply operations to corrupt the state file. To enable destroy after
  # intentionally removing this protection:
  #   1. Remove or set to 'false': lifecycle { prevent_destroy = true }
  #   2. Run: terraform apply
  #   3. Then destroy can proceed.
  # lifecycle {
  #   prevent_destroy = true
  # }

  tags = var.tags
}
