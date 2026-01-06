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
echo "Rclone terbaru dan dependensi berhasil terpasang."
echo "Sekarang jalankan: rclone config"
echo "Pilih 'N' pada 'Use auto config' dan masukkan"
echo "JSON token yang didapat dari laptop Anda."
echo "------------------------------------------------"