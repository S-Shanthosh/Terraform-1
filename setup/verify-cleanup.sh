workspace $ cd setup/
setup $ ls
bootstrap.sh  resource-cleanup.sh  teardown.sh  tf-save.sh  tf-start.sh
setup $ echo "=== EC2 Instances ===" && \
> aws ec2 describe-instances --region ap-south-1 --query 'Reservations[*].Instances[*].{ID:InstanceId,State:State.Name}' --output table --no-cli-pager
=== EC2 Instances ===
setup $ 
setup $ echo "=== S3 Buckets ===" && \
> aws s3 ls --no-cli-pager
=== S3 Buckets ===
setup $ 
setup $ echo "=== DynamoDB Tables ===" && \
> aws dynamodb list-tables --region ap-south-1 --no-cli-pager
=== DynamoDB Tables ===
{
    "TableNames": []
}
setup $ 
setup $ echo "=== Lambda Functions ===" && \
> aws lambda list-functions --region ap-south-1 --query 'Functions[*].FunctionName' --output table --no-cli-pager
=== Lambda Functions ===
setup $ 
setup $ echo "=== CodeBuild Projects ===" && \
> aws codebuild list-projects --region ap-south-1 --no-cli-pager
=== CodeBuild Projects ===
{
    "projects": []
}
setup $ 
setup $ echo "=== EventBridge Rules ===" && \
> aws events list-rules --region ap-south-1 --no-cli-pager
=== EventBridge Rules ===
{
    "Rules": []
}
setup $ 
setup $ echo "=== IAM Roles (custom only) ===" && \
> aws iam list-roles --query 'Roles[?starts_with(RoleName, `CodeBuild`) || starts_with(RoleName, `Lambda-Terraform`)].RoleName' --output table --no-cli-pager
