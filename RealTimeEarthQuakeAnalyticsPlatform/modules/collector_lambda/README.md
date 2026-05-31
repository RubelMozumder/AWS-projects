# collector_lambda Terraform Module

This module deploys the collector Lambda function using a deployment package stored in S3.

## Usage Example

```hcl
module "collector_lambda" {
  source              = "./modules/collector_lambda"
  lambda_function_name = "earthquake-collector"
  lambda_s3_bucket     = "my-lambda-artifacts-bucket"
  lambda_s3_key        = "collector/lambda_collector.zip"
  lambda_handler       = "lambda_collector.lambda_handler"
  lambda_runtime       = "python3.12"
  lambda_memory_size   = 256
  lambda_timeout       = 30
  lambda_environment   = {
    USGS_FEED_URL = "https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/all_hour.geojson"
    # Add more environment variables as needed
  }
}
```

## Inputs
- `lambda_function_name`: Name of the Lambda function
- `lambda_s3_bucket`: S3 bucket containing the Lambda deployment package
- `lambda_s3_key`: S3 key for the Lambda deployment package
- `lambda_handler`: Lambda handler (e.g., `lambda_collector.lambda_handler`)
- `lambda_runtime`: Lambda runtime (e.g., `python3.12`)
- `lambda_memory_size`: Memory size in MB (default: 256)
- `lambda_timeout`: Timeout in seconds (default: 30)
- `lambda_environment`: Map of environment variables

## Outputs
- `lambda_function_name`: Name of the deployed Lambda function
- `lambda_function_arn`: ARN of the deployed Lambda function
