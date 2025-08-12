#!/bin/bash
source "$(dirname "$0")/env.sh"
source "$UTILS_DIR/logging.sh"

BACKUP_FILE="$BASE_DIR/backup_$(date +%F_%H-%M-%S).zip"

log_info "กำลังสำรองข้อมูลไปยัง $BACKUP_FILE"
zip -r "$BACKUP_FILE" "$REPORT_DIR" > /dev/null
log_success "สำรองข้อมูลเสร็จสิ้น"
