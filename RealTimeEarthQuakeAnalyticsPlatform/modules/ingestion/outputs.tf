# =============================================================
# Module: ingestion — Outputs
# =============================================================
# Consumed by:
#   collector_lambda module  → api_gateway_invoke_url, api_key_value
#   processing module        → firehose_stream_arn (Transformer Lambda target)
#   root outputs.tf          → api_gateway_invoke_url (for console visibility)

output "api_gateway_invoke_url" {
  description = "Full invocation URL for POST /ingest. Set this as INGEST_API_URL in the collector Lambda environment."
  value       = "${aws_api_gateway_stage.v1.invoke_url}/ingest"
}

output "api_gateway_id" {
  description = "REST API ID. Used for console navigation and referencing in future modules."
  value       = aws_api_gateway_rest_api.ingest.id
}

output "api_gateway_stage_name" {
  description = "Deployed stage name (e.g. v1). Useful for constructing the invoke URL manually."
  value       = aws_api_gateway_stage.v1.stage_name
}

output "api_key_value" {
  description = "API key secret for the collector Lambda. Set this as INGEST_API_KEY in the collector Lambda environment."
  value       = aws_api_gateway_api_key.collector.value
  sensitive   = true
}

output "api_key_id" {
  description = "API key resource ID. Useful for referencing the key in the AWS console."
  value       = aws_api_gateway_api_key.collector.id
}

output "firehose_stream_name" {
  description = "Name of the Kinesis Firehose delivery stream."
  value       = aws_kinesis_firehose_delivery_stream.raw.name
}

output "firehose_stream_arn" {
  description = "ARN of the Kinesis Firehose delivery stream. Passed to the Transformer Lambda module (Stack 3b) as its event source."
  value       = aws_kinesis_firehose_delivery_stream.raw.arn
}

output "firehose_role_arn" {
  description = "ARN of the Firehose IAM delivery role. Needed when attaching the Transformer Lambda to Firehose in Stack 3b."
  value       = aws_iam_role.firehose.arn
}
