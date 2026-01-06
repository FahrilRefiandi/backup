#!/bin/bash

BASE_DIR=$(dirname "$(readlink -f "$0")")

sudo apt update
sudo apt install -y jq mysql-client
sudo curl https://rclone.org/install.sh | sudo bash

mkdir -p "$BASE_DIR/destination"

if [ ! -f "$BASE_DIR/config.json" ]; then
    cp "$BASE_DIR/config.json.example" "$BASE_DIR/config.json"
fi

echo "------------------------------------------------"
read -p "Masukkan jam untuk jadwal backup (0-23): " B_HOUR
read -p "Masukkan menit untuk jadwal backup (0-59): " B_MIN

BACKUP_SCRIPT="$BASE_DIR/backup.sh"
LOG_FILE="$BASE_DIR/backup.log"
CRON_JOB="$B_MIN $B_HOUR * * * /bin/bash $BACKUP_SCRIPT >> $LOG_FILE 2>&1"

(sudo crontab -l 2>/dev/null; echo "$CRON_JOB") | sudo crontab -

echo "Cronjob berhasil ditambahkan dengan sistem logging."
echo "Log dapat dilihat di: $LOG_FILE"
echo "------------------------------------------------"
echo "Rclone terbaru dan dependensi berhasil terpasang."
echo "Sekarang jalankan: rclone config"
echo "Pilih 'N' pada 'Use web browser' dan masukkan"
echo "JSON token yang didapat dari laptop Anda."
echo "------------------------------------------------"