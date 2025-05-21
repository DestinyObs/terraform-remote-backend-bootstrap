#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# First argument: environment name (e.g. dev, prod)
# Second argument: AWS region (e.g. us-east-1)
ENVIRONMENT=$1
AWS_REGION=$2

# If any of the required arguments are missing, print usage info and exit
if [[ -z "$ENVIRONMENT" || -z "$AWS_REGION" ]]; then
  echo "Usage: ./bootstrap.sh <environment> <aws-region>"
  exit 1
fi

# Generate a short, unique identifier using the current timestamp and md5 hash
SHORT_ID=$(date +%s | md5sum | cut -c 1-6)

# Append the short ID and "destinyobs" to the names to ensure uniqueness across multiple users
BUCKET_NAME="terraform-state-${ENVIRONMENT}-${SHORT_ID}-destinyobs"
DYNAMO_TABLE="terraform-lock-${ENVIRONMENT}-${SHORT_ID}-destinyobs"

# Announce the creation of the S3 bucket
echo "Creating S3 bucket: $BUCKET_NAME in $AWS_REGION..."

# Check if the bucket already exists
if aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
  echo "Bucket already exists. Skipping creation..."
else
  # Special case: us-east-1 does not need LocationConstraint
  if [[ "$AWS_REGION" == "us-east-1" ]]; then
    aws s3api create-bucket --bucket "$BUCKET_NAME" --region "$AWS_REGION"
  else
    aws s3api create-bucket \
      --bucket "$BUCKET_NAME" \
      --region "$AWS_REGION" \
      --create-bucket-configuration LocationConstraint="$AWS_REGION"
  fi
  echo "Bucket created: $BUCKET_NAME"
fi

# Enable versioning on the S3 bucket to support state file history and recovery
echo "Enabling versioning on bucket..."
aws s3api put-bucket-versioning \
  --bucket "$BUCKET_NAME" \
  --versioning-configuration Status=Enabled

# Apply strict public access block to prevent accidental exposure of state files
echo "Blocking public access on bucket..."
aws s3api put-public-access-block \
  --bucket "$BUCKET_NAME" \
  --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

# Announce the creation of the DynamoDB table used for Terraform state locking
echo "Creating DynamoDB table for locking: $DYNAMO_TABLE..."

# Check if the DynamoDB table already exists
if aws dynamodb describe-table --table-name "$DYNAMO_TABLE" --region "$AWS_REGION" 2>/dev/null; then
  echo "DynamoDB table already exists. Skipping creation..."
else
  # Create a DynamoDB table with a single string key called "LockID"
  aws dynamodb create-table \
    --table-name "$DYNAMO_TABLE" \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region "$AWS_REGION"
  echo "DynamoDB table created."
fi

# Output a ready-to-use backend.tf block using the generated resources
echo ""
echo "Done! Add this to your backend.tf:"
echo ""
cat <<EOF
terraform {
  backend "s3" {
    bucket         = "$BUCKET_NAME"
    key            = "env/$ENVIRONMENT/terraform.tfstate"
    region         = "$AWS_REGION"
    dynamodb_table = "$DYNAMO_TABLE"
    encrypt        = true
  }
}
EOF