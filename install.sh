#!/bin/bash

PACKAGES=("jq" "rclone" "mysql-client")

echo "Checking dependencies..."

for pkg in "${PACKAGES[@]}"; do
    if ! command -v "$pkg" &> /dev/null; then
        echo "Installing $pkg..."
        sudo apt update && sudo apt install -y "$pkg"
    else
        echo "$pkg is already installed."
    fi
done

echo "All dependencies are ready."