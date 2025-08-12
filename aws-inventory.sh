#!/bin/zsh
# aws-inventory.sh - Gathers and displays information about AWS resources.

echo "🚀 Starting AWS Resource Inventory..."
echo "========================================"

# --- EC2 Instances ---
echo "\n🔎 [EC2 Instances]"
INSTANCES_DATA=$(aws ec2 describe-instances \
  --query 'Reservations[*].Instances[*].[InstanceId,InstanceType,State.Name,PublicIpAddress,KeyName,Tags[?Key==`Name`].Value | [0]]' \
  --output json)

# ตรวจสอบว่ามี Instance หรือไม่
if [ -z "$(echo $INSTANCES_DATA | jq '.[]')" ]; then
    echo "  No EC2 instances found."
else
    # ใช้ jq เพื่อจัดรูปแบบข้อมูล
    echo "$INSTANCES_DATA" | jq -r '
      .[] | .[] |
      "----------------------------------------\n" +
      "  ID:         " + .[0] + "\n" +
      "  Name:       " + (.[5] // "N/A") + "\n" +
      "  Type:       " + .[1] + "\n" +
      "  State:      " + .[2] + "\n" +
      "  Public IP:  " + (.[3] // "N/A") + "\n" +
      "  Key Pair:   " + (.[4] // "N/A")
    '
fi

echo "\n========================================"
echo "✅ Inventory complete."
