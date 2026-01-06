#!/bin/bash

sudo apt update
sudo apt install -y jq rclone mysql-client

mkdir -p destination

if [ ! -f config.json ]; then
    cp config.json.example config.json
fi

echo "------------------------------------------------"
echo "Instalasi Berhasil."
echo "Sekarang silakan buat remote baru di rclone."
echo "Gunakan nama remote gdrive"
echo "------------------------------------------------"

rclone config