#!/bin/bash
source "$(dirname "$0")/../env.sh"
source "$UTILS_DIR/logging.sh"

TIMESTAMP=$(date +%F_%H-%M-%S)
OUTPUT_JSON="$REPORT_DIR/aws_inventory_$TIMESTAMP.json"

log_info "เริ่มดึงข้อมูล AWS Inventory..."

bash "$INVENTORY_DIR/ec2.sh" > ec2.json
bash "$INVENTORY_DIR/s3.sh" > s3.json
bash "$INVENTORY_DIR/rds.sh" > rds.json
bash "$INVENTORY_DIR/iam.sh" > iam.json

jq -s 'reduce .[] as $item ({}; . * $item)' ec2.json s3.json rds.json iam.json > "$OUTPUT_JSON"

rm ec2.json s3.json rds.json iam.json
log_success "บันทึก AWS Inventory ที่ $OUTPUT_JSON"
