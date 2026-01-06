#!/bin/bash

CONFIG_FILE="/root/backup/scripts/backup_config.json"
PYTHON_UPLOADER="/root/backup/scripts/upload.py"
SERVICE_ACCOUNT_JSON="/root/backup/scripts/service-account.json"
GDRIVE_FOLDER_ID="ISI_DENGAN_ID_FOLDER_GOOGLE_DRIVE_ANDA"

if ! command -v jq &> /dev/null; then
    echo "Error: 'jq' tidak ditemukan."
    exit 1
fi

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Konfigurasi tidak ditemukan."
    exit 1
fi

DEST_DIR=$(jq -r '.settings.destination_directory' "$CONFIG_FILE")
DB_USER=$(jq -r '.settings.db_user' "$CONFIG_FILE")
DB_PASS=$(jq -r '.settings.db_password' "$CONFIG_FILE")

mkdir -p "$DEST_DIR"
TIMESTAMP=$(date +%Y-%m-%d-%H%M%S)

echo "### Memulai Backup (Service Account) ###"

jq -c '.items[]' "$CONFIG_FILE" | while read -r item; do
    PROJECT_NAME=$(echo "$item" | jq -r '.name')
    PROJECT_PATH=$(echo "$item" | jq -r '.path')
    DB_NAME=$(echo "$item" | jq -r '.db_name // ""')

    mapfile -t FILES_TO_BACKUP < <(echo "$item" | jq -r '.files[]')

    if [ ! -d "$PROJECT_PATH" ]; then
        continue
    fi

    STAGING_DIR="$DEST_DIR/staging_${PROJECT_NAME}_${TIMESTAMP}"
    mkdir -p "$STAGING_DIR"

    echo "Memproses: $PROJECT_NAME..."

    if [ -n "$DB_NAME" ]; then
        mysqldump -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" > "$STAGING_DIR/database_dump.sql"
    fi

    if [ ${#FILES_TO_BACKUP[@]} -gt 0 ]; then
        for file_item in "${FILES_TO_BACKUP[@]}"; do
            cp -a "$PROJECT_PATH/$file_item" "$STAGING_DIR/"
        done
    fi

    backup_filename="backup-${PROJECT_NAME}-${TIMESTAMP}.tar.gz"
    local_file="$DEST_DIR/$backup_filename"
    
    tar -czf "$local_file" -C "$STAGING_DIR" .

    if [ $? -eq 0 ]; then
        echo "  -> Mengunggah ke Google Drive..."
        python3 "$PYTHON_UPLOADER" "$local_file" "$GDRIVE_FOLDER_ID" "$SERVICE_ACCOUNT_JSON"
        
        if [ $? -eq 0 ]; then
            rm "$local_file"
            echo "Sukses: $PROJECT_NAME terunggah."
        fi
    fi

    rm -rf "$STAGING_DIR"
done

echo "Selesai."