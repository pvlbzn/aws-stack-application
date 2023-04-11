#!/bin/bash

CLI_PROFILE=default

# Validate the CloudFormation template
aws cloudformation validate-template \
  --profile $CLI_PROFILE \
  --template-body file://main.yml \
