#!/bin/bash
set -e

echo "ℹ️  เริ่มทำงาน AWS Automation ครบวงจร"

# ===== 1. ตรวจ dependencies =====
if ! command -v aws &>/dev/null; then
    echo "❌ ไม่พบ AWS CLI"
    exit 1
fi
if ! command -v scp &>/dev/null; then
    echo "❌ ไม่พบ scp"
    exit 1
fi

echo "✅ Dependencies ครบถ้วน"

# ===== 2. ดึง Public DNS ของ EC2 =====
echo "ℹ️  กำลังดึงข้อมูล EC2 จาก AWS..."
EC2_HOST=$(aws ec2 describe-instances \
    --query "Reservations[0].Instances[0].PublicDnsName" \
    --output text)

if [[ "$EC2_HOST" == "None" || -z "$EC2_HOST" ]]; then
    echo "❌ ไม่พบ EC2 ที่มี Public DNS"
    exit 1
fi

EC2_USER="ec2-user" # ปรับตาม AMI
REMOTE_DIR="/home/ec2-user/aws-reports"
KEY_FILE="$HOME/termux-aws-automation/MyEC2Key.pem"

# ตรวจสิทธิ์ key
chmod 400 "$KEY_FILE"

echo "✅ พบ EC2 Host: $EC2_HOST"

# ===== 3. รัน AWS Inventory =====
echo "ℹ️  เริ่มดึงข้อมูล AWS Inventory..."
REPORT_DIR="$(pwd)/aws-reports"
mkdir -p "$REPORT_DIR"
echo "{ \"sample\": \"inventory\" }" > "$REPORT_DIR/report.json" # แทนที่ด้วยคำสั่งจริง
echo "✅ บันทึก AWS Inventory ที่ $REPORT_DIR"

# ===== 4. สำรองข้อมูล =====
BACKUP_FILE="$(pwd)/backup_$(date +%F_%H-%M-%S).zip"
echo "ℹ️  กำลังสำรองข้อมูลไปยัง $BACKUP_FILE"
zip -rq "$BACKUP_FILE" aws-reports
echo "✅ สำรองข้อมูลเสร็จสิ้น"

# ===== 5. อัปโหลดไปยัง EC2 =====
echo "ℹ️  อัปโหลดรายงานไปยัง EC2 $EC2_HOST"
scp -i "$KEY_FILE" -o StrictHostKeyChecking=no -r aws-reports "$EC2_USER@$EC2_HOST:$REMOTE_DIR" || {
    echo "❌ อัปโหลดล้มเหลว"
    exit 1
}
echo "✅ อัปโหลดสำเร็จ"
