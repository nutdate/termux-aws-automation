#!/bin/bash
# สคริปต์สำหรับค้นหาและช่วยลบทรัพยากรเก่าใน Region ap-southeast-1

REGION="ap-southeast-1"

echo "==============================================="
echo "=== เริ่มการตรวจสอบทรัพยากรเก่าที่ค้างอยู่ ==="
echo "==============================================="

echo ""
echo "--- 1. กำลังค้นหา EC2 Instances ที่ทำงานอยู่ ---"
RUNNING_INSTANCES=$(aws ec2 describe-instances --region $REGION --filters "Name=instance-state-name,Values=running" --query "Reservations[*].Instances[*].InstanceId" --output text)

if [ -z "$RUNNING_INSTANCES" ]; then
  echo "✅ ไม่พบ EC2 instance ที่ทำงานอยู่"
else
  echo "⚠️ พบ EC2 Instances ที่ทำงานอยู่: $RUNNING_INSTANCES"
  echo "   ➡️  ใช้คำสั่งนี้เพื่อลบทิ้ง: aws ec2 terminate-instances --region $REGION --instance-ids $RUNNING_INSTANCES"
fi

echo ""
echo "--- 2. กำลังค้นหา Elastic IPs ที่ไม่ได้ใช้งาน (ที่กินเงิน) ---"
UNATTACHED_EIPS=$(aws ec2 describe-addresses --region $REGION --filters "Name=instance-id,Values=" --query "Addresses[*].AllocationId" --output text)

if [ -z "$UNATTACHED_EIPS" ]; then
  echo "✅ ไม่พบ Elastic IPs ที่ไม่ได้ใช้งาน"
else
  echo "⚠️ พบ Elastic IPs ที่ไม่ได้ใช้งาน:"
  echo "$UNATTACHED_EIPS"
  echo "   ➡️  ใช้คำสั่งเหล่านี้เพื่อลบ (แนะนำให้รันทีละบรรทัด):"
  for EIP_ALLOC in $UNATTACHED_EIPS; do
    echo "      aws ec2 release-address --region $REGION --allocation-id $EIP_ALLOC"
  done
fi

echo ""
echo "--- 3. กำลังค้นหา VPCs ที่ไม่ใช่ Default ---"
NON_DEFAULT_VPCS=$(aws ec2 describe-vpcs --region $REGION --filters "Name=is-default,Values=false" --query "Vpcs[*].VpcId" --output text)

if [ -z "$NON_DEFAULT_VPCS" ]; then
  echo "✅ ไม่พบ VPCs อื่นๆ นอกจาก Default VPC"
else
  echo "⚠️ พบ VPCs ที่ไม่ใช่ Default:"
  echo "$NON_DEFAULT_VPCS"
  echo "   ❗️ คำเตือน: การลบ VPC จะลบทุกอย่างข้างในด้วย!"
  echo "   ➡️  คุณต้องเข้าไปลบ VPC เหล่านี้ด้วยตัวเองจาก 'หน้าเว็บ AWS Console' เพื่อความปลอดภัย"
fi

echo ""
echo "==============================================="
echo "=== การตรวจสอบเสร็จสิ้น ==="
echo "==============================================="
