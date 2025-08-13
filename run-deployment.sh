#!/bin/bash
set +e  # อย่าหยุดถ้ามี error

MAX_RETRIES=3
STACK_NAME="MyHighSpeedStack"
REGION="ap-southeast-1"

echo "ℹ️ กำลังค้นหาข้อมูล AWS อัตโนมัติ..."

# ดึง KeyPair แรก
KEY_PAIR=$(aws ec2 describe-key-pairs \
    --region $REGION \
    --query 'KeyPairs[0].KeyName' \
    --output text 2>/dev/null)

if [ "$KEY_PAIR" == "None" ] || [ -z "$KEY_PAIR" ]; then
    echo "❌ ไม่พบ KeyPair ใน region $REGION กรุณาสร้างก่อน"
    exit 1
fi

# ดึง Hosted Zone ID และ Domain
HOSTED_ZONE_ID=$(aws route53 list-hosted-zones \
    --query 'HostedZones[0].Id' \
    --output text 2>/dev/null | sed 's|/hostedzone/||')

DOMAIN_NAME=$(aws route53 list-hosted-zones \
    --query 'HostedZones[0].Name' \
    --output text 2>/dev/null | sed 's/\.$//')

if [ "$HOSTED_ZONE_ID" == "None" ] || [ -z "$HOSTED_ZONE_ID" ]; then
    echo "❌ ไม่พบ Hosted Zone ใน Route53 กรุณาสร้างก่อน"
    exit 1
fi

echo "✅ ใช้ KeyPair: $KEY_PAIR"
echo "✅ ใช้ Domain: $DOMAIN_NAME"
echo "✅ ใช้ HostedZoneId: $HOSTED_ZONE_ID"
echo "-----------------------------------------"

# เริ่ม deploy
for attempt in $(seq 1 $MAX_RETRIES); do
    echo "🚀 [รอบที่ $attempt] เริ่ม Deploy Stack..."

    aws cloudformation deploy \
        --template-file my-aws-stack.yml \
        --stack-name $STACK_NAME \
        --capabilities CAPABILITY_NAMED_IAM \
        --region $REGION \
        --parameter-overrides \
            KeyPairName=$KEY_PAIR \
            DomainName=$DOMAIN_NAME \
            HostedZoneId=$HOSTED_ZONE_ID

    if [ $? -eq 0 ]; then
        echo "✅ Deploy สำเร็จ"
        break
    else
        echo "❌ Deploy ล้มเหลว (รอบที่ $attempt)"
        aws cloudformation describe-stack-events \
            --stack-name $STACK_NAME \
            --region $REGION \
            --query 'StackEvents[0:5].[Timestamp,ResourceStatus,LogicalResourceId,ResourceStatusReason]' \
            --output table

        if [ $attempt -lt $MAX_RETRIES ]; then
            echo "🔄 กำลังลบ Stack ที่พัง และจะลองใหม่..."
            aws cloudformation delete-stack --stack-name $STACK_NAME --region $REGION
            aws cloudformation wait stack-delete-complete --stack-name $STACK_NAME --region $REGION
        else
            echo "💥 ลองครบ $MAX_RETRIES รอบแล้ว ยังไม่สำเร็จ"
        fi
    fi
done

echo "🎯 ทำงานขั้นตอนต่อไป..."
