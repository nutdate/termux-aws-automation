#!/bin/bash
set -e

# กำหนดตัวแปรที่ใช้
IMAGE_ID="ami-08d17f4183e481a35" # Ubuntu 22.04 LTS
INSTANCE_TYPE="t2.micro"
KEY_NAME="MyEC2Key"
SECURITY_GROUP_ID="sg-0a9200140505b96d4"
SUBNET_ID="subnet-09df73b4da999ada1"
ALLOCATION_ID="eipalloc-0a0657932d960ed26"
DOMAIN_NAME="aws-ec2.ddnsgeek.com"
HOSTED_ZONE_NAME="ddnsgeek.com"
VPC_ID="vpc-0005f26bdc173a550"

echo "--- เริ่มต้นการสร้างและตั้งค่า AWS EC2 Instance ---"

# ตรวจสอบ IPv6 VPC
VPC_IPV6_CIDR=$(aws ec2 describe-vpcs --vpc-ids "$VPC_ID" --query "Vpcs[0].Ipv6CidrBlockAssociationSet[0].Ipv6CidrBlock" --output text)
if [[ "$VPC_IPV6_CIDR" == "None" || -z "$VPC_IPV6_CIDR" ]]; then
  echo "VPC ยังไม่มี IPv6 CIDR Block กำลังกำหนดให้..."
  aws ec2 associate-vpc-cidr-block --vpc-id "$VPC_ID" --amazon-provided-ipv6-cidr-block
  aws ec2 wait vpc-ipv6-cidr-block-association-state --vpc-id "$VPC_ID" --state associated
  VPC_IPV6_CIDR=$(aws ec2 describe-vpcs --vpc-ids "$VPC_ID" --query "Vpcs[0].Ipv6CidrBlockAssociationSet[0].Ipv6CidrBlock" --output text)
fi

# ตรวจสอบ IPv6 Subnet
SUBNET_IPV6_CIDR=$(aws ec2 describe-subnets --subnet-ids "$SUBNET_ID" --query "Subnets[0].Ipv6CidrBlockAssociationSet[0].Ipv6CidrBlock" --output text)
if [[ "$SUBNET_IPV6_CIDR" == "None" || -z "$SUBNET_IPV6_CIDR" ]]; then
  echo "Subnet ยังไม่มี IPv6 CIDR Block กำลังกำหนดให้..."
  VPC_IPV6_PREFIX=$(echo "$VPC_IPV6_CIDR" | cut -d: -f1-4)
  for i in {0..255}; do
    if aws ec2 associate-subnet-cidr-block --subnet-id "$SUBNET_ID" --ipv6-cidr-block "${VPC_IPV6_PREFIX}:${i}::/64" >/dev/null 2>&1; then
      echo "กำหนด IPv6 CIDR Block: ${VPC_IPV6_PREFIX}:${i}::/64 สำเร็จ ✅"
      SUBNET_IPV6_CIDR="${VPC_IPV6_PREFIX}:${i}::/64"
      break
    fi
  done
else
  echo "Subnet มี IPv6 CIDR Block แล้ว: $SUBNET_IPV6_CIDR"
fi

# ตรวจสอบว่ามี Instance อยู่หรือยัง
INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=My-FreeTier-EC2-Instance" "Name=instance-state-name,Values=running" \
  --query "Reservations[0].Instances[0].InstanceId" --output text)

if [[ "$INSTANCE_ID" == "None" || -z "$INSTANCE_ID" ]]; then
  echo "ไม่พบ Instance ที่กำลังรัน กำลังสร้างใหม่..."
  
  NETWORK_INTERFACE_JSON=$(cat <<EOF
[
  {
    "SubnetId": "$SUBNET_ID",
    "DeviceIndex": 0,
    "AssociatePublicIpAddress": true,
    "Ipv6Addresses": [{"Ipv6Address": "${SUBNET_IPV6_CIDR%/*}1234"}],
    "Groups": ["$SECURITY_GROUP_ID"]
  }
]
EOF
  )
  
  INSTANCE_ID=$(aws ec2 run-instances \
    --image-id "$IMAGE_ID" \
    --count 1 \
    --instance-type "$INSTANCE_TYPE" \
    --key-name "$KEY_NAME" \
    --network-interfaces "$NETWORK_INTERFACE_JSON" \
    --block-device-mappings "DeviceName=/dev/sda1,Ebs={VolumeSize=30,DeleteOnTermination=true}" \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=My-FreeTier-EC2-Instance}]' \
    --query "Instances[0].InstanceId" --output text)
  
  echo "สร้าง EC2 Instance แล้ว: $INSTANCE_ID"
  echo "รอให้ Instance พร้อมใช้งาน..."
  aws ec2 wait instance-running --instance-ids "$INSTANCE_ID"
  echo "Instance พร้อมใช้งานแล้ว!"
else
  echo "พบ Instance ที่กำลังรันแล้ว: $INSTANCE_ID"
fi

# เชื่อม Elastic IP
EIP_ASSOC_ID=$(aws ec2 describe-addresses --allocation-id "$ALLOCATION_ID" --query "Addresses[0].AssociationId" --output text)
if [[ -z "$EIP_ASSOC_ID" ]]; then
  echo "เชื่อม Elastic IP ($ALLOCATION_ID) กับ Instance ($INSTANCE_ID)..."
  aws ec2 associate-address --instance-id "$INSTANCE_ID" --allocation-id "$ALLOCATION_ID"
  echo "เชื่อม Elastic IP สำเร็จ!"
else
  echo "Elastic IP เชื่อมโยงอยู่แล้ว"
fi

# ดึง IP ออกมาแสดง
IPV4_ADDRESS=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --query "Reservations[0].Instances[0].PublicIpAddress" --output text)
IPV6_ADDRESS=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --query "Reservations[0].Instances[0].NetworkInterfaces[0].Ipv6Addresses[0].Ipv6Address" --output text)

echo "IPv4: $IPV4_ADDRESS"
echo "IPv6: $IPV6_ADDRESS"

# อัปเดต Route53 DNS
HOSTED_ZONE_ID=$(aws route53 list-hosted-zones-by-name --dns-name "$HOSTED_ZONE_NAME." --query "HostedZones[0].Id" --output text | cut -d'/' -f3)

aws route53 change-resource-record-sets --hosted-zone-id "$HOSTED_ZONE_ID" --change-batch "{
  \"Changes\": [
    {
      \"Action\": \"UPSERT\",
      \"ResourceRecordSet\": {
        \"Name\": \"$DOMAIN_NAME\",
        \"Type\": \"A\",
        \"TTL\": 300,
        \"ResourceRecords\": [{\"Value\": \"$IPV4_ADDRESS\"}]
      }
    },
    {
      \"Action\": \"UPSERT\",
      \"ResourceRecordSet\": {
        \"Name\": \"$DOMAIN_NAME\",
        \"Type\": \"AAAA\",
        \"TTL\": 300,
        \"ResourceRecords\": [{\"Value\": \"$IPV6_ADDRESS\"}]
      }
    }
  ]
}"

echo "--- ตั้งค่า EC2 และ DNS เสร็จสมบูรณ์ ---"
echo "SSH ใช้งานได้ด้วยคำสั่ง:"
echo "ssh -i \"$KEY_NAME.pem\" ubuntu@$IPV4_ADDRESS"
