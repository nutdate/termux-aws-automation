#!/bin/bash
aws s3api list-buckets --query 'Buckets[].Name' --profile "$AWS_PROFILE"
