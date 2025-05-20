#!/bin/bash

set -e

ENVIRONMENT=$1
AWS_REGION=$2

if [[ -z "$ENVIRONMENT" || -z "$AWS_REGION" ]]; then
  echo "Usage: ./bootstrap.sh <environment> <aws-region>"
  exit 1
fi

# Generate a unique short ID
SHORT_ID=$(date +%s | md5sum | cut -c 1-6)

# Append destinyobs and short ID to ensure uniqueness
BUCKET_NAME="terraform-state-${ENVIRONMENT}-${SHORT_ID}-destinyobs"
DYNAMO_TABLE="terraform-lock-${ENVIRONMENT}-${SHORT_ID}-destinyobs"

echo "Creating S3 bucket: $BUCKET_NAME in $AWS_REGION..."

# Check if the bucket already exists
if aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
  echo "Bucket already exists. Skipping creation..."
else
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

echo "Enabling versioning on bucket..."
aws s3api put-bucket-versioning \
  --bucket "$BUCKET_NAME" \
  --versioning-configuration Status=Enabled

echo "Blocking public access on bucket..."
aws s3api put-public-access-block \
  --bucket "$BUCKET_NAME" \
  --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

echo "Creating DynamoDB table for locking: $DYNAMO_TABLE..."

if aws dynamodb describe-table --table-name "$DYNAMO_TABLE" --region "$AWS_REGION" 2>/dev/null; then
  echo "DynamoDB table already exists. Skipping creation..."
else
  aws dynamodb create-table \
    --table-name "$DYNAMO_TABLE" \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region "$AWS_REGION"
  echo "DynamoDB table created."
fi

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
