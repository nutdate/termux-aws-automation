#!/bin/bash
set -e

# path หลักของโปรเจ็กต์
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
UTILS_DIR="$BASE_DIR/utils"
INVENTORY_DIR="$BASE_DIR/inventory"

# โหลดฟังก์ชัน
source "$UTILS_DIR/check-deps.sh"
source "$UTILS_DIR/logging.sh"
source "$BASE_DIR/env.sh"

log_info "เริ่มทำงาน AWS Automation"

# ตรวจ dependencies
check_dependencies

# ดึงข้อมูล AWS
bash "$INVENTORY_DIR/aws-inventory.sh"

# สำรองข้อมูล
bash "$BASE_DIR/backup.sh"

# อัปโหลดไป EC2
bash "$BASE_DIR/deploy-to-ec2.sh"

log_success "ทำงานเสร็จสิ้น"
