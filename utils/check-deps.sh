#!/bin/bash

check_dependencies() {
    local deps=("aws" "jq" "git" "ssh")
    local missing=()

    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &>/dev/null; then
            missing+=("$dep")
        fi
    done

    if [ ${#missing[@]} -ne 0 ]; then
        echo "❌ ขาด dependencies: ${missing[*]}"
        echo "➡ ติดตั้งด้วยคำสั่ง: pkg install ${missing[*]}"
        exit 1
    else
        echo "✅ dependencies ครบถ้วน"
    fi
}
