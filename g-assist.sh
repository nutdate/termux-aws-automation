#!/bin/zsh
# g-assist.sh - A flexible Git helper script for Termux

# ฟังก์ชันแสดงวิธีใช้งาน
show_usage() {
    echo "Usage: ./g-assist.sh [command]"
    echo ""
    echo "Commands:"
    echo "  push      - Add all files, commit with a message, and push to the current branch."
    echo "  pull      - Pull the latest changes from the remote repository."
    echo "  status    - Show the working tree status."
    echo "  help      - Show this help message."
    echo ""
}

# ตรวจสอบว่ามีคำสั่งส่งมาหรือไม่
if [ -z "$1" ]; then
    show_usage
    exit 1
fi

# ตัวแปรเก็บคำสั่ง
COMMAND=$1

# เริ่มการทำงานตามคำสั่งที่รับมา
case $COMMAND in
    "push")
        echo "Starting automated push..."

        # ถามข้อความสำหรับ commit
        echo -n "Please enter your commit message: "
        read COMMIT_MSG

        # ตรวจสอบว่าข้อความว่างหรือไม่
        if [[ -z "$COMMIT_MSG" ]]; then
            echo "❌ Error: Commit message cannot be empty."
            exit 1
        fi

        # ดึงชื่อ branch ปัจจุบัน
        CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)

        echo "➡️ Adding all files..."
        git add .

        echo "➡️ Committing with message: '$COMMIT_MSG'"
        git commit -m "$COMMIT_MSG"

        echo "➡️ Pushing to branch '$CURRENT_BRANCH'..."
        git push origin $CURRENT_BRANCH

        echo "✅ Push successful!"
        ;;

    "pull")
        echo "Pulling latest changes..."
        git pull
        echo "✅ Pull successful!"
        ;;

    "status")
        echo "Current repository status:"
        git status
        ;;

    "help")
        show_usage
        ;;

    *)
        echo "❌ Error: Unknown command '$COMMAND'"
        show_usage
        exit 1
        ;;
esac
