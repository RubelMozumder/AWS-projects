BOOTSTRAP_FOLDER="serverless-web-backend/bootstrap-stacks"
AWS_ACCOUNT_BOOTSTRAP_FILE="account-bootstrap-stack.yaml"
# aws s3 cp s3://bucket-for-projects-321/${BOOTSTRAP_FOLDER}/${AWS_ACCOUNT_BOOTSTRAP_FILE} .

AWS_MULTI_STACK_FILE="serverless-web-backend-stack.yaml"
SERVERLESS_WEB_FOLDER="serverless-web-backend/cloudFormation"

aws s3 cp s3://bucket-for-projects-321/${SERVERLESS_WEB_FOLDER}/${AWS_MULTI_STACK_FILE} .

# aws cloudformation deploy \
#   --stack-name account-bootstrap \
#   --template-file ${AWS_ACCOUNT_BOOTSTRAP_FILE} \
#   --capabilities CAPABILITY_NAMED_IAM

aws cloudformation deploy \
  --stack-name serverless-web-backend-stack \
  --template-file ${AWS_MULTI_STACK_FILE} \
  --capabilities CAPABILITY_NAMED_IAM \
  --no-fail-on-empty-changeset

# aws cloudformation describe-stack-events --stack-name account-bootstrap


