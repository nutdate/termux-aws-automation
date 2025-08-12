#!/bin/bash
source "$(dirname "$0")/env.sh"
source "$UTILS_DIR/logging.sh"

log_info "อัปโหลดรายงานไปยัง EC2 $EC2_HOST"
scp -r "$REPORT_DIR" "$EC2_USER@$EC2_HOST:$EC2_PATH"
log_success "อัปโหลดเสร็จสิ้น"
