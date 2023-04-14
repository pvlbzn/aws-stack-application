#!/bin/bash

STACK_NAME=awsbootstrap
REGION=us-east-1
CLI_PROFILE=default

EC2_INSTANCE_TYPE=t2.micro

# Programmatically get the AWS account ID from the AWS CLI
AWS_ACCOUNT_ID=`aws sts get-caller-identity --profile awsbootstrap \
  --query "Account" --output text`
CODEPIPELINE_BUCKET="$STACK_NAME-$REGION-codepipeline-$AWS_ACCOUNT_ID"

# Deploy the CloudFormation template
echo -e "\n\n=========== Deploying main.yml ==========="

# Deploy S3
aws cloudformation deploy \
  --region $REGION \
  --profile $CLI_PROFILE \
  --stack-name $STACK_NAME-setup \
  --template-file setup.yaml \
  --no-fail-on-empty-changeset \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameters-overrides \
    CodePipelineBucket=$CODEPIPELINE_BUCKET

# Deploy infra
aws cloudformation deploy \
  --region $REGION \
  --profile $CLI_PROFILE \
  --stack-name $STACK_NAME \
  --template-file main.yaml \
  --no-fail-on-empty-changeset \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides \
    EC2InstanceType=$EC2_INSTANCE_TYPE \

# If the deploy succeeded, show the DNS name of the created instance
if [ $? -eq 0 ]; then
  aws cloudformation list-exports \
    --profile default \
    --query "Exports[?Name=='InstanceDNS'].Value"
fi