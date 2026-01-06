#!/bin/bash

PACKAGES=("jq" "python3-pip" "mysql-client")

for pkg in "${PACKAGES[@]}"; do
    if ! command -v "$pkg" &> /dev/null; then
        sudo apt update && sudo apt install -y "$pkg"
    fi
done

if [ -f "requirements.txt" ]; then
    pip3 install -r requirements.txt
fi