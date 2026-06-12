variable "lambda_function_name" {
  description = "Name of the Lambda function"
  type        = string
}

variable "lambda_s3_bucket" {
  description = "S3 bucket containing Lambda deployment package"
  type        = string
}

variable "lambda_s3_key" {
  description = "S3 key for Lambda deployment package"
  type        = string
}

variable "lambda_handler" {
  description = "Lambda handler (e.g., lambda_collector.lambda_handler)"
  type        = string
}

variable "lambda_runtime" {
  description = "Lambda runtime (e.g., python3.12)"
  type        = string
}

variable "lambda_memory_size" {
  description = "Lambda memory size in MB"
  type        = number
  default     = 256
}

variable "lambda_timeout" {
  description = "Lambda timeout in seconds"
  type        = number
  default     = 30
}

variable "lambda_environment" {
  description = "Map of environment variables for Lambda"
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Map of tags applied to all resources in this module."
  type        = map(string)
  default     = {}
}
