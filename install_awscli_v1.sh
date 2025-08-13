#!/bin/bash
set -e

echo "อัปเดตแพ็กเกจและติดตั้ง python3-pip ก่อน"
pkg update -y
pkg install -y python python-pip

echo "ติดตั้ง AWS CLI v1 ผ่าน pip"
pip install --upgrade --user awscli

echo "เพิ่ม ~/.local/bin เข้า PATH ชั่วคราว (ถ้ายังไม่มี)"
export PATH=$HOME/.local/bin:$PATH

echo "ตรวจสอบเวอร์ชัน aws cli"
aws --version

echo "ติดตั้งเสร็จเรียบร้อย!"
echo "ถ้าใช้งานใน shell ใหม่ ให้เพิ่มบรรทัดนี้ใน ~/.bashrc หรือ ~/.zshrc เพื่อเพิ่ม PATH อัตโนมัติ"
echo 'export PATH=$HOME/.local/bin:$PATH'
