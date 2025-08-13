#!/bin/bash

set -e

# ----------------------
# แก้ไขตรงนี้ด้วย Warp+ License Key ของคุณ
LICENSE_KEY="W02ZKd71-ZqM39R67-1843kMFJ"
# ----------------------

echo "=== อัปเดตระบบ ==="
sudo apt-get update -y
sudo apt-get install -y curl

echo "=== ติดตั้ง Cloudflare Warp Client ==="
curl https://pkg.cloudflareclient.com/pubkey.gpg | sudo tee /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg >/dev/null
echo "deb [signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ focal main" | sudo tee /etc/apt/sources.list.d/cloudflare-client.list
sudo apt-get update -y
sudo apt-get install -y cloudflare-warp

echo "=== ลงทะเบียน Warp Client ==="
sudo warp-cli register

echo "=== ใส่ Warp+ License Key ==="
sudo warp-cli set-license $LICENSE_KEY

echo "=== เชื่อมต่อ Warp+ ==="
sudo warp-cli connect

echo "=== ตรวจสอบสถานะ Warp ==="
sudo warp-cli status

echo "=== ตั้งค่าให้ Warp ทำงานเป็น default route ==="
sudo warp-cli enable-always-on

echo "=== เสร็จสิ้น! ==="
echo "คุณสามารถตรวจสอบ IP ปัจจุบันได้ด้วยคำสั่ง: curl https://ifconfig.me"

