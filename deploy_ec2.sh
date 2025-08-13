#!/bin/bash
set -e
trap 'echo "❌ เกิดข้อผิดพลาดที่บรรทัด $LINENO"; exit 1' ERR

# โหลด config
source ./config.sh

# ฟังก์ชันตรวจสอบตัวแปร
validate_vars() {
    echo "🔍 กำลังตรวจสอบค่าตัวแปร..."
    local vars=("IMAGE_ID" "INSTANCE_TYPE" "KEY_NAME" "SECURITY_GROUP_ID" \
                "SUBNET_ID" "ALLOCATION_ID" "DOMAIN_NAME" "HOSTED_ZONE_NAME" "VPC_ID")
    for var in "${vars[@]}"; do
        if [ -z "${!var}" ]; then
            echo "❌ ตัวแปร $var ยังไม่มีค่า"; exit 1
        fi
    done
    echo "✅ ค่าตัวแปรครบถ้วน"
}

# ตรวจว่าเรียกด้วย --dry-run หรือไม่
if [[ "$1" == "--dry-run" ]]; then
    DRY_RUN=true
else
    DRY_RUN=false
fi

# ฟังก์ชันใช้แทนการเรียก aws โดยตรง
aws_cmd() {
    if $DRY_RUN; then
        echo "[DRY-RUN] aws $*"
    else
        aws "$@"
    fi
}

# เริ่มทำงาน
validate_vars
echo "--- เริ่มสร้างและตั้งค่า EC2 Instance ---"

# 1. ตรวจสอบและกำหนด IPv6 ให้กับ VPC และ Subnet
echo "กำลังตรวจสอบการตั้งค่า IPv6..."
VPC_IPV6_CIDR=$(aws_cmd ec2 describe-vpcs --vpc-ids "$VPC_ID" --query "Vpcs[0].Ipv6CidrBlockAssociationSet[0].Ipv6CidrBlock" --output text || echo "None")
if [ "$VPC_IPV6_CIDR" = "None" ]; then
    echo "VPC ยังไม่มี IPv6 CIDR Block กำลังกำหนดให้..."
    aws_cmd ec2 associate-vpc-cidr-block --vpc-id "$VPC_ID" --amazon-provided-ipv6-cidr-block
    aws_cmd ec2 wait vpc-ipv6-cidr-block-association-state --vpc-id "$VPC_ID" --state "associated"
    VPC_IPV6_CIDR=$(aws_cmd ec2 describe-vpcs --vpc-ids "$VPC_ID" --query "Vpcs[0].Ipv6CidrBlockAssociationSet[0].Ipv6CidrBlock" --output text)
fi

SUBNET_IPV6_CIDR=$(aws_cmd ec2 describe-subnets --subnet-ids "$SUBNET_ID" --query "Subnets[0].Ipv6CidrBlockAssociationSet[0].Ipv6CidrBlock" --output text || echo "None")
if [ "$SUBNET_IPV6_CIDR" = "None" ]; then
    echo "Subnet ยังไม่มี IPv6 CIDR Block กำลังกำหนดให้..."
    VPC_IPV6_PREFIX=$(echo "$VPC_IPV6_CIDR" | cut -d: -f1-4)
    for i in $(seq 0 255); do
        if aws_cmd ec2 associate-subnet-cidr-block --subnet-id "$SUBNET_ID" --ipv6-cidr-block "${VPC_IPV6_PREFIX}:${i}::/64" > /dev/null 2>&1; then
            echo "กำหนด IPv6 CIDR Block: ${VPC_IPV6_PREFIX}:${i}::/64 สำเร็จ ✅"
            break
        fi
    done
fi
echo "การตั้งค่า IPv6 เสร็จสมบูรณ์ ✅"

# 2. สร้าง EC2 Instance (ถ้าไม่มี)
echo "กำลังตรวจสอบว่ามี EC2 Instance อยู่แล้วหรือไม่..."
INSTANCE_ID=$(aws_cmd ec2 describe-instances --filters "Name=tag:Name,Values=My-FreeTier-EC2-Instance" "Name=instance-state-name,Values=running" --query "Reservations[0].Instances[0].InstanceId" --output text 2>/dev/null)

if [ -z "$INSTANCE_ID" ] || [ "$INSTANCE_ID" = "None" ]; then
    echo "ไม่พบ Instance กำลังสร้างใหม่... ⏳"
    INSTANCE_ID=$(aws_cmd ec2 run-instances \
        --image-id "$IMAGE_ID" \
        --count 1 \
        --instance-type "$INSTANCE_TYPE" \
        --key-name "$KEY_NAME" \
        --security-group-ids "$SECURITY_GROUP_ID" \
        --subnet-id "$SUBNET_ID" \
        --ipv6-address-count 1 \
        --block-device-mappings "DeviceName=/dev/sda1,Ebs={VolumeSize=30,DeleteOnTermination=true}" \
        --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=My-FreeTier-EC2-Instance}]' \
        --query "Instances[0].InstanceId" --output text)
    echo "EC2 Instance ถูกสร้างแล้วด้วย ID: $INSTANCE_ID"
    echo "กำลังรอให้ Instance พร้อมใช้งาน... ⏰"
    aws_cmd ec2 wait instance-running --instance-ids "$INSTANCE_ID"
    echo "Instance พร้อมใช้งานแล้ว 🎉"
else
    echo "พบ Instance ที่ใช้งานอยู่แล้ว ID: $INSTANCE_ID"
fi

# 3. เชื่อมโยง Elastic IP (IPv4)
echo "กำลังตรวจสอบการเชื่อมโยง Elastic IP..."
EIP_ASSOC_ID=$(aws_cmd ec2 describe-addresses --allocation-id "$ALLOCATION_ID" --query "Addresses[0].AssociationId" --output text 2>/dev/null)
if [ -z "$EIP_ASSOC_ID" ]; then
    echo "กำลังเชื่อมโยง Elastic IP: $ALLOCATION_ID ไปยัง Instance: $INSTANCE_ID"
    aws_cmd ec2 associate-address --instance-id "$INSTANCE_ID" --allocation-id "$ALLOCATION_ID"
    echo "เชื่อมโยง Elastic IP สำเร็จ ✅"
else
    echo "Elastic IP ได้ถูกเชื่อมโยงอยู่แล้ว ✅"
fi

# 4. ดึง IP Address
echo "กำลังดึง IP Address ของ Instance... 🌐"
IPV4_ADDRESS=$(aws_cmd ec2 describe-instances --instance-ids "$INSTANCE_ID" --query "Reservations[0].Instances[0].PublicIpAddress" --output text)
IPV6_ADDRESS=$(aws_cmd ec2 describe-instances --instance-ids "$INSTANCE_ID" --query "Reservations[0].Instances[0].NetworkInterfaces[0].Ipv6Addresses[0].Ipv6Address" --output text)

echo "Public IPv4 Address: $IPV4_ADDRESS"
echo "Public IPv6 Address: $IPV6_ADDRESS"

# 5. อัปเดต DNS Record ใน Route 53
echo "กำลังอัปเดต DNS records..."
HOSTED_ZONE_ID=$(aws_cmd route53 list-hosted-zones-by-name --dns-name "$HOSTED_ZONE_NAME." --query "HostedZones[0].Id" --output text | cut -d'/' -f3)

aws_cmd route53 change-resource-record-sets \
    --hosted-zone-id "$HOSTED_ZONE_ID" \
    --change-batch '{
        "Changes": [{
            "Action": "UPSERT",
            "ResourceRecordSet": {
                "Name": "'"$DOMAIN_NAME"'",
                "Type": "A",
                "TTL": 300,
                "ResourceRecords": [{"Value": "'"$IPV4_ADDRESS"'"}]
            }
        },{
            "Action": "UPSERT",
            "ResourceRecordSet": {
                "Name": "'"$DOMAIN_NAME"'",
                "Type": "AAAA",
                "TTL": 300,
                "ResourceRecords": [{"Value": "'"$IPV6_ADDRESS"'"}]
            }
        }]
    }'
echo "อัปเดต DNS records สำเร็จ ✅"

echo "--- การตั้งค่าทั้งหมดเสร็จสมบูรณ์ ---"
echo "ssh -i \"$KEY_NAME.pem\" ubuntu@$IPV4_ADDRESS"
