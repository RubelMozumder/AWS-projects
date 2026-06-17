# Terraform Strategy: Backend Bootstrap and Module Orchestration

## Goal
Use a single root Terraform configuration while avoiding a separate backend stack deployment.

## Key Constraint
Terraform backend configuration is loaded during `terraform init`, before modules/resources/outputs are evaluated.

Because of this, backend values cannot reference module outputs like:
- `module.foundation.terraform_state_bucket_id`
- `module.foundation.terraform_lock_table_name`

## Practical Approach
1. Start with local state for bootstrap.
2. Deploy `module.foundation` from the root module.
3. Read foundation outputs for state bucket and lock table names.
4. Configure backend block with literal values.
5. Run state migration to S3.
6. Continue all future deploys with remote state.

## Implementation Layout
- Keep backend resources (state S3 bucket + lock DynamoDB table) in foundation module.
- Keep a backend block in root config commented until first foundation apply is complete.
- After first apply, fill backend block values from outputs and migrate state.

## Recommended Commands
Use AWS CLI profile `RubDev` unless intentionally changing profile.

```bash
export AWS_PROFILE=RubDev
cd RealTimeEarthQuakeAnalyticsPlatform

# Bootstrap using local state
terraform init -backend=false
terraform apply -target=module.foundation

# Inspect output values to copy into backend config
terraform output terraform_state_bucket_id
terraform output terraform_lock_table_name

# After updating backend block with copied values
terraform init -migrate-state

# Continue normal deployments
terraform apply
```

## Backend Block Example
```hcl
terraform {
  backend "s3" {
    bucket         = "<terraform_state_bucket_id>"
    key            = "earthquake-analytics/dev/terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "<terraform_lock_table_name>"
    encrypt        = true
  }
}
```

## Reusing Module Outputs in Root
Inside root module calls, use:
- `module.foundation.<output_name>`

Example:
```hcl
module "scheduler" {
  source = "./modules/scheduler"

  # example once scheduler needs foundation outputs
  # data_bucket_arn = module.foundation.data_bucket_arn
  # kms_key_arn     = module.foundation.kms_key_arn
}
```

## Notes
- This is not a separate backend deployment; it is a one-time bootstrap + migration.
- Backend config must be static at init time.
- After migration, team collaboration uses remote state and DynamoDB locking safely.
