# =============================================================
# Module: ingestion
# =============================================================
# Provisions the ingestion layer of the earthquake analytics pipeline:
#
#   Collector Lambda
#       │  POST /ingest  (x-api-key header)
#       ▼
#   REST API Gateway        ← entry point, throttling, auth
#       │  AWS service integration (no Lambda hop)
#       ▼
#   Kinesis Data Firehose   ← buffers, batches, delivers
#       │  extended S3 delivery
#       ▼
#   S3 raw/                 ← GZIP-compressed JSON, Hive-partitioned
#
# Resources created:
#   CloudWatch
#     - aws_cloudwatch_log_group        → Firehose error logs (/aws/kinesisfirehose/...)
#     - aws_cloudwatch_log_stream       → S3Delivery stream within that group
#
#   IAM — Firehose delivery role
#     - aws_iam_role.firehose           → assumed by Firehose service
#     - aws_iam_role_policy.firehose    → S3 write + KMS encrypt + CloudWatch logs
#
#   IAM — API Gateway role
#     - aws_iam_role.api_gw             → assumed by API Gateway service
#     - aws_iam_role_policy.api_gw      → firehose:PutRecord on this stream only
#
#   Kinesis Firehose
#     - aws_kinesis_firehose_delivery_stream.raw
#         destination: extended_s3
#         prefix:      raw/year=.../month=.../day=.../hour=.../ (dynamic partitioning)
#         compression: GZIP
#
#   API Gateway
#     - aws_api_gateway_rest_api              → REST API (REGIONAL endpoint)
#     - aws_api_gateway_resource              → /ingest path
#     - aws_api_gateway_method                → POST (api_key_required = true)
#     - aws_api_gateway_integration           → AWS service → Firehose PutRecord
#     - aws_api_gateway_method_response       → 200 response declaration
#     - aws_api_gateway_integration_response  → maps Firehose response to HTTP 200
#     - aws_api_gateway_deployment            → snapshot of current API definition
#     - aws_api_gateway_stage                 → v1 (or var.stage_name)
#     - aws_api_gateway_api_key               → collector API key
#     - aws_api_gateway_usage_plan            → rate + burst limits
#     - aws_api_gateway_usage_plan_key        → links API key to usage plan
# =============================================================


# -------------------------------------------------------------
# Data Sources
# -------------------------------------------------------------

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}


# =============================================================
# CloudWatch — Firehose Error Log Group
# =============================================================
# Firehose writes delivery errors here when records fail to land in S3.
# Without this group, delivery errors are silently dropped.
# The log group must exist before Firehose is created.

resource "aws_cloudwatch_log_group" "firehose" {
  name              = "/aws/kinesisfirehose/${var.name_prefix}-raw-delivery"
  retention_in_days = 14
  tags              = var.tags
}

resource "aws_cloudwatch_log_stream" "s3_delivery" {
  name           = "S3Delivery"
  log_group_name = aws_cloudwatch_log_group.firehose.name
}


# =============================================================
# IAM — Firehose Delivery Role
# =============================================================
# Firehose assumes this role to write records to S3 and log errors.
#
# Trust policy:
#   The sts:ExternalId condition scopes the trust to this specific
#   AWS account. This prevents confused deputy attacks where another
#   account's Firehose could assume this role.
#
# Permissions granted:
#   S3Write     → AbortMultipartUpload, GetBucketLocation, GetObject,
#                 ListBucket, ListBucketMultipartUploads, PutObject
#                 (all required by Firehose for reliable S3 delivery)
#   KMSEncrypt  → GenerateDataKey + Decrypt on the CMK
#                 (required because the data lake bucket uses KMS SSE)
#   CloudWatch  → PutLogEvents to the Firehose log group only

resource "aws_iam_role" "firehose" {
  name = "${var.name_prefix}-firehose-delivery-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "firehose.amazonaws.com" }
      Action    = "sts:AssumeRole"
      Condition = {
        StringEquals = {
          "sts:ExternalId" = data.aws_caller_identity.current.account_id
        }
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "firehose" {
  name = "${var.name_prefix}-firehose-delivery-policy"
  role = aws_iam_role.firehose.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3Write"
        Effect = "Allow"
        Action = [
          "s3:AbortMultipartUpload",
          "s3:GetBucketLocation",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:ListBucketMultipartUploads",
          "s3:PutObject",
        ]
        Resource = [
          var.s3_bucket_arn,
          "${var.s3_bucket_arn}/*",
        ]
      },
      {
        Sid    = "KMSEncrypt"
        Effect = "Allow"
        Action = [
          "kms:GenerateDataKey",
          "kms:Decrypt",
        ]
        Resource = var.kms_key_arn
        Condition = {
          StringEquals = {
            "kms:ViaService" = "s3.${data.aws_region.current.name}.amazonaws.com"
          }
          StringLike = {
            "kms:EncryptionContext:aws:s3:arn" = "${var.s3_bucket_arn}/*"
          }
        }
      },
      {
        Sid      = "CloudWatchLogs"
        Effect   = "Allow"
        Action   = ["logs:PutLogEvents"]
        Resource = "${aws_cloudwatch_log_group.firehose.arn}:*"
      },
    ]
  })
}


# =============================================================
# IAM — API Gateway Role
# =============================================================
# API Gateway assumes this role to call firehose:PutRecord.
# Without this role, the AWS service integration cannot write to Firehose.
# The policy is scoped to a single action on a single stream (least privilege).

resource "aws_iam_role" "api_gw" {
  name = "${var.name_prefix}-apigw-firehose-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "apigateway.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "api_gw" {
  name = "${var.name_prefix}-apigw-firehose-policy"
  role = aws_iam_role.api_gw.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "FirehosePutRecord"
      Effect   = "Allow"
      Action   = ["firehose:PutRecord"]
      Resource = aws_kinesis_firehose_delivery_stream.raw.arn
    }]
  })
}


# =============================================================
# Kinesis Data Firehose — Raw Delivery Stream
# =============================================================
# Receives JSON records from API Gateway and delivers them to S3 raw/.
#
# Prefix uses Firehose dynamic partitioning tokens so S3 objects land
# in Hive-compatible partitions that Athena and Glue can query directly:
#
#   raw/year=2025/month=05/day=23/hour=14/<uuid>.json.gz
#
# Error prefix: records that fail delivery (S3 error, KMS denied, etc.)
# are written here for inspection and reprocessing:
#
#   raw-errors/<error-type>/year=2025/month=05/day=23/<uuid>.json.gz
#
# Compression: GZIP reduces S3 storage by ~70–80% for JSON payloads.
# Raw files are not queried directly — Athena queries processed/ instead.
#
# Note: the Transformer Lambda processor (Stack 3b) is not wired in yet.
# When Stack 3b is built, add a `processing_configuration` block here
# and grant the Transformer Lambda ARN to the Firehose role.

resource "aws_kinesis_firehose_delivery_stream" "raw" {
  name        = "${var.name_prefix}-raw-delivery"
  destination = "extended_s3"

  extended_s3_configuration {
    role_arn   = aws_iam_role.firehose.arn
    bucket_arn = var.s3_bucket_arn

    prefix              = "${var.raw_data_prefix}year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/hour=!{timestamp:HH}/"
    error_output_prefix = "raw-errors/!{firehose:error-output-type}/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/"

    buffering_size     = var.firehose_buffer_size_mb
    buffering_interval = var.firehose_buffer_interval_seconds

    compression_format = "GZIP"

    cloudwatch_logging_options {
      enabled         = true
      log_group_name  = aws_cloudwatch_log_group.firehose.name
      log_stream_name = aws_cloudwatch_log_stream.s3_delivery.name
    }
  }

  tags = var.tags
}


# =============================================================
# REST API Gateway
# =============================================================

# REGIONAL endpoint: cheaper than EDGE (no CloudFront distribution)
# and sufficient for a single-region pipeline.
resource "aws_api_gateway_rest_api" "ingest" {
  name        = "${var.name_prefix}-ingest-api"
  description = "Earthquake analytics ingestion endpoint — receives collector events and writes to Firehose"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = var.tags
}

# /ingest path
resource "aws_api_gateway_resource" "ingest" {
  rest_api_id = aws_api_gateway_rest_api.ingest.id
  parent_id   = aws_api_gateway_rest_api.ingest.root_resource_id
  path_part   = "ingest"
}

# POST /ingest
# api_key_required = true: every request must include x-api-key header.
# This prevents accidental or unauthorised writes to the pipeline.
resource "aws_api_gateway_method" "post_ingest" {
  rest_api_id      = aws_api_gateway_rest_api.ingest.id
  resource_id      = aws_api_gateway_resource.ingest.id
  http_method      = "POST"
  authorization    = "NONE"
  api_key_required = true
}

# AWS service integration: API Gateway → Firehose PutRecord
#
# type = "AWS" triggers a direct AWS service call — no Lambda needed.
# API GW signs the request using the api_gw IAM role and calls the
# Firehose PutRecord API on behalf of the client.
#
# Request mapping template (VTL):
#   Firehose PutRecord expects the body to be base64-encoded under "Data".
#   $util.base64Encode($input.body) encodes the raw JSON request body.
#   The DeliveryStreamName is resolved at plan time via Terraform interpolation.
#
# Note: records in raw/ S3 files are concatenated without separators
# (standard Firehose behaviour). The Transformer Lambda (Stack 3b)
# will output properly newline-delimited Parquet in processed/.

resource "aws_api_gateway_integration" "post_ingest" {
  rest_api_id             = aws_api_gateway_rest_api.ingest.id
  resource_id             = aws_api_gateway_resource.ingest.id
  http_method             = aws_api_gateway_method.post_ingest.http_method
  type                    = "AWS"
  integration_http_method = "POST"
  uri                     = "arn:aws:apigateway:${data.aws_region.current.name}:firehose:action/PutRecord"
  credentials             = aws_iam_role.api_gw.arn

  request_templates = {
    "application/json" = jsonencode({
      DeliveryStreamName = aws_kinesis_firehose_delivery_stream.raw.name
      Record = {
        Data = "$util.base64Encode($input.body)"
      }
    })
  }
}

# Declare the 200 success response shape on the method.
resource "aws_api_gateway_method_response" "post_ingest_200" {
  rest_api_id = aws_api_gateway_rest_api.ingest.id
  resource_id = aws_api_gateway_resource.ingest.id
  http_method = aws_api_gateway_method.post_ingest.http_method
  status_code = "200"

  response_models = {
    "application/json" = "Empty"
  }
}

# Map Firehose's response back to HTTP 200.
# No response template needed — the Firehose JSON response
# is passed through as-is (EncryptionId, RecordId fields).
resource "aws_api_gateway_integration_response" "post_ingest_200" {
  rest_api_id = aws_api_gateway_rest_api.ingest.id
  resource_id = aws_api_gateway_resource.ingest.id
  http_method = aws_api_gateway_method.post_ingest.http_method
  status_code = aws_api_gateway_method_response.post_ingest_200.status_code

  depends_on = [aws_api_gateway_integration.post_ingest]
}

# Deployment snapshot.
# The `triggers` hash ensures a new deployment is created whenever
# the API definition changes — without it, Terraform would not
# redeploy after method/integration updates.
resource "aws_api_gateway_deployment" "ingest" {
  rest_api_id = aws_api_gateway_rest_api.ingest.id

  triggers = {
    redeploy = sha1(join(",", [
      aws_api_gateway_resource.ingest.id,
      aws_api_gateway_method.post_ingest.id,
      aws_api_gateway_integration.post_ingest.id,
      aws_api_gateway_method_response.post_ingest_200.id,
      aws_api_gateway_integration_response.post_ingest_200.id,
    ]))
  }

  # create_before_destroy: the new deployment is live before the old one
  # is removed, preventing a gap in service during updates.
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "v1" {
  rest_api_id   = aws_api_gateway_rest_api.ingest.id
  deployment_id = aws_api_gateway_deployment.ingest.id
  stage_name    = var.stage_name

  tags = var.tags
}

# API key for the Collector Lambda.
# The collector sets x-api-key: <value> on every POST request.
# Value is auto-generated by AWS and exposed as a sensitive output.
resource "aws_api_gateway_api_key" "collector" {
  name    = "${var.name_prefix}-collector-key"
  enabled = true
  tags    = var.tags
}

# Usage plan: enforces rate and burst limits per API key.
# Prevents a misconfigured collector from flooding the pipeline.
resource "aws_api_gateway_usage_plan" "ingest" {
  name = "${var.name_prefix}-ingest-plan"

  api_stages {
    api_id = aws_api_gateway_rest_api.ingest.id
    stage  = aws_api_gateway_stage.v1.stage_name
  }

  throttle_settings {
    rate_limit  = var.api_rate_limit_rps
    burst_limit = var.api_burst_limit
  }

  tags = var.tags
}

# Associates the collector API key with the usage plan.
# Without this, the API key exists but has no stage/plan attached
# and all requests return 403 Forbidden.
resource "aws_api_gateway_usage_plan_key" "collector" {
  key_id        = aws_api_gateway_api_key.collector.id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.ingest.id
}
