#!/bin/bash

echo -e "Running deployment script"

STACK_NAME=awsbootstrap
REGION=us-east-1
CLI_PROFILE=default

EC2_INSTANCE_TYPE=t2.micro

# HTTPS
DOMAIN=aws.edbase.app
CERT=`aws acm list-certificates --region $REGION --profile $CLI_PROFILE --output text \
  --query "CertificateSummaryList[?DomainName=='$DOMAIN'].CertificateArn | [0]"`

# Programmatically get the AWS account ID from the AWS CLI
AWS_ACCOUNT_ID=`aws sts get-caller-identity --profile default \
  --query "Account" --output text`

# S3 buckets
CODEPIPELINE_BUCKET="$STACK_NAME-$REGION-codepipeline-$AWS_ACCOUNT_ID"
CFN_BUCKET="$STACK_NAME-cfn-$AWS_ACCOUNT_ID"

echo -e "AWS Account ID: ${AWS_ACCOUNT_ID}"
echo -e "AWS CodePipeline bucket name: ${CODEPIPELINE_BUCKET}"
echo -e "CFN bucket: ${CFN_BUCKET}"
echo -e "Certificate ARN: ${CERT}"

GH_ACCESS_TOKEN=$(cat ~/.github/aws-bootstrap-access-token)
GH_OWNER=$(cat ~/.github/aws-bootstrap-owner)
GH_REPO=$(cat ~/.github/aws-bootstrap-repo)
GH_BRANCH=main

echo -e "Deploying S3 AWS CloudFormation bucket"

# Deploy S3
aws cloudformation deploy \
  --region $REGION \
  --profile $CLI_PROFILE \
  --stack-name $STACK_NAME-setup \
  --template-file setup.yaml \
  --no-fail-on-empty-changeset \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides \
    CodePipelineBucket=$CODEPIPELINE_BUCKET \
    CloudFormationBucket=$CFN_BUCKET

echo -e "Packaging main.yaml"
mkdir -p ./cfn_output

PACKAGE_ERR="$(aws cloudformation package \
  --region $REGION \
  --profile $CLI_PROFILE \
  --template main.yaml \
  --s3-bucket $CFN_BUCKET \
  --output-template-file ./cfn_output/main.yaml 2>&1)"

if ! [[ $PACKAGE_ERR =~ "Successfully packaged artifacts" ]]; then
  echo "ERROR while running 'aws cloudformation package' command:"
  echo $PACKAGE_ERR
  exit 1
fi

echo -e "Deploying main.yml"
# Deploy infra
aws cloudformation deploy \
  --region $REGION \
  --profile $CLI_PROFILE \
  --stack-name $STACK_NAME \
  --template-file ./cfn_output/main.yaml \
  --no-fail-on-empty-changeset \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides \
    EC2InstanceType=$EC2_INSTANCE_TYPE \
    Domain=$DOMAIN \
    Certificate=$CERT \
    GitHubOwner=$GH_OWNER \
    GitHubRepo=$GH_REPO \
    GitHubBranch=$GH_BRANCH \
    GitHubPersonalAccessToken=$GH_ACCESS_TOKEN \
    CodePipelineBucket=$CODEPIPELINE_BUCKET

# If the deploy succeeded, show the DNS name of the created instance
if [ $? -eq 0 ]; then
  aws cloudformation list-exports \
    --profile default \
    --query "Exports[?ends_with(Name,'LBEndpoint')].Value"
fi
