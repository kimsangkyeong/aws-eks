#!/bin/bash

PROJECT_NAME=${1:-tb07297}
ENVIRONMENT=${2:-dev}
ACCOUNT_ID=$(aws sts get-caller-identity | jq -r ".Account")

VPC_TAG_NAME="vpc-${PROJECT_NAME}-${ENVIRONMENT}"
VPC_ID=$(aws ec2 describe-vpcs \
  --filters "Name=tag:Name,Values=${VPC_TAG_NAME}" \
  --query "Vpcs[0].VpcId" \
  --output text)

# 조회 결과가 없을 경우 예외 처리
if [ "$VPC_ID" == "None" ] || [ -z "$VPC_ID" ]; then
    echo "❌ Error: VPC를 찾을 수 없습니다."
    exit 1
fi

if [ -z "$PROJECT_NAME" -o -z "$ENVIRONMENT" ]; then
    echo "Usage: ./render0.sh <project_name> <environment>"
    echo "Example: ./render0.sh tb07297 dev"
    exit 1
fi

TEMPLATE_FILE="eksctl_cluster_template.yaml"
OUTPUT_FILE="$PROJECT_NAME-$ENVIRONMENT.eksctl_cluster_template.yaml"

sed -e "s/<account_id>/${ACCOUNT_ID}/g" \
    -e "s/<project_name>/${PROJECT_NAME}/g" \
    -e "s/<environment>/${ENVIRONMENT}/g" \
    -e "s/<vpc_id>/${VPC_ID}/g" \
    $TEMPLATE_FILE > $OUTPUT_FILE
