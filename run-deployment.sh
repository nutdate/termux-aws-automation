#!/bin/bash
# สคริปต์หลักที่ "ฉลาด" สำหรับการ Deploy CloudFormation Stack

STACK_NAME="MyHighSpeedStack"
TEMPLATE_FILE="my-aws-stack.yml"
REGION="ap-southeast-1"

# --- ข้อมูลที่ต้องกำหนด ---
KEY_PAIR="my-main-git-key"
HOSTED_ZONE_ID="Z099282910M32TRYMG9Z8"
DOMAIN_NAME="nutdata.net"

echo "--- เริ่มกระบวนการ Deploy สคริปต์ ---"

# 1. ตรวจสอบสถานะของ Stack เก่า
echo "1. กำลังตรวจสอบ Stack เก่าที่ชื่อ '$STACK_NAME'..."
STACK_STATUS=$(aws cloudformation describe-stacks --stack-name $STACK_NAME --region $REGION --query "Stacks[0].StackStatus" --output text 2>/dev/null)

if [ $? -eq 0 ]; then
  # ถ้าเจอ Stack
  echo "   -> พบ Stack เก่าอยู่ในสถานะ: $STACK_STATUS"
  if [[ "$STACK_STATUS" == "ROLLBACK_COMPLETE" || "$STACK_STATUS" == "CREATE_FAILED" || "$STACK_STATUS" == "UPDATE_ROLLBACK_COMPLETE" ]]; then
    read -p "   -> Stack นี้อยู่ในสถานะที่พัง ต้องการลบทิ้งก่อนหรือไม่? (y/n): " choice
    if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
      echo "   -> กำลังลบ Stack '$STACK_NAME'..."
      aws cloudformation delete-stack --stack-name $STACK_NAME --region $REGION
      echo "   -> กำลังรอให้ Stack ลบเสร็จสมบูรณ์ (อาจใช้เวลา 2-3 นาที)..."
      aws cloudformation wait stack-delete-complete --stack-name $STACK_NAME --region $REGION
      echo "   -> ลบ Stack เก่าเรียบร้อยแล้ว"
    else
      echo "   -> ยกเลิกการ Deploy เนื่องจากผู้ใช้ไม่ต้องการลบ Stack ที่ค้างอยู่"
      exit 1
    fi
  fi
else
  echo "   -> ไม่พบ Stack เก่า ทางสะดวก"
fi

# 2. เริ่มการ Deploy
echo ""
echo "2. กำลังเริ่ม Deploy ระบบใหม่..."
aws cloudformation deploy \
  --template-file $TEMPLATE_FILE \
  --stack-name $STACK_NAME \
  --capabilities CAPABILITY_IAM \
  --region $REGION \
  --parameter-overrides \
    KeyPairName=$KEY_PAIR \
    HostedZoneId=$HOSTED_ZONE_ID \
    DomainName=$DOMAIN_NAME

if [ $? -eq 0 ]; then
  echo ""
  echo "✅ Deploy สำเร็จ!"
  echo "--- กำลังแสดงผลลัพธ์ ---"
  aws cloudformation describe-stacks --stack-name $STACK_NAME --region $REGION --query "Stacks[0].Outputs"
else
  echo ""
  echo "❌ Deploy ล้มเหลว กรุณาตรวจสอบข้อผิดพลาด"
fi
