#!/bin/bash
aws ec2 describe-instances --region "$AWS_REGION" --profile "$AWS_PROFILE"
