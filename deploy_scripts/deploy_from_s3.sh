#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

BUCKET_NAME="bucket-for-projects-321"
BUCKET_KEY_PREFIX="serverless-web-backend/cloudFormation"
BOOTSTRAP_FOLDER="serverless-web-backend/bootstrap-stacks"
AWS_ACCOUNT_BOOTSTRAP_FILE="account-bootstrap-stack.yaml"
AWS_MULTI_STACK_FILE="serverless-web-backend-stack.yaml"
SERVERLESS_WEB_FOLDER="ServerlessWebBackend/CloudFormation"
ROOT_TEMPLATE_PATH="${REPO_ROOT}/${SERVERLESS_WEB_FOLDER}/${AWS_MULTI_STACK_FILE}"
NESTED_TEMPLATE_FOLDER="${REPO_ROOT}/${SERVERLESS_WEB_FOLDER}"


# Make zip the code
SNS_LAMBDA_CODE_PATH="${REPO_ROOT}/ServerlessWebBackend/pythonCode/dynamodb_to_sns/"
SQS_LAMBDA_CODE_PATH="${REPO_ROOT}/ServerlessWebBackend/pythonCode/sqs_to_dynamodb/"
bash ${REPO_ROOT}/code_base_scripts/zip_python_code.sh -s ${SNS_LAMBDA_CODE_PATH} -o ${SNS_LAMBDA_CODE_PATH}dynamodb_to_sns.zip
bash ${REPO_ROOT}/code_base_scripts/zip_python_code.sh -s ${SQS_LAMBDA_CODE_PATH} -o ${SQS_LAMBDA_CODE_PATH}sqs_to_dynamodb.zip

# Copy Lambda code to S3
SWS_PYTHON_CODE_S3_PATH="bucket-for-projects-321/serverless-web-backend/python-code/"
bash ${REPO_ROOT}/AWS-s3/copy-folder-to-s3-bucket.sh ${SQS_LAMBDA_CODE_PATH}sqs_to_dynamodb.zip ${SWS_PYTHON_CODE_S3_PATH}
bash ${REPO_ROOT}/AWS-s3/copy-folder-to-s3-bucket.sh ${SNS_LAMBDA_CODE_PATH}dynamodb_to_sns.zip ${SWS_PYTHON_CODE_S3_PATH}

# aws s3 cp "s3://${BUCKET_NAME}/${BOOTSTRAP_FOLDER}/${AWS_ACCOUNT_BOOTSTRAP_FILE}" .
aws s3 cp "${NESTED_TEMPLATE_FOLDER}" "s3://${BUCKET_NAME}/${BUCKET_KEY_PREFIX}" --recursive

# aws cloudformation deploy \
#   --stack-name account-bootstrap \
#   --template-file "${AWS_ACCOUNT_BOOTSTRAP_FILE}" \
#   --capabilities CAPABILITY_NAMED_IAM \
#   --no-fail-on-empty-changeset

aws cloudformation deploy \
  --stack-name serverless-web-backend-stack \
  --template-file "${ROOT_TEMPLATE_PATH}" \
  --capabilities CAPABILITY_NAMED_IAM \
  --no-fail-on-empty-changeset


