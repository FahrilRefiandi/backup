#!/bin/bash

echo "Installing dependencies..."
sudo apt update
sudo apt install -y jq rclone mysql-client

echo "Setup selesai. Silakan jalankan 'rclone config' untuk menghubungkan cloud Anda."