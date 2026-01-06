#!/bin/bash

CONFIG_FILE="/root/backup/scripts/backup_config.json"

check_dependencies() {
    local deps=("jq" "rclone" "mysqldump")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            echo "Error: $dep tidak ditemukan. Jalankan ./setup.sh atau install manual."
            exit 1
        fi
    done
}

check_dependencies

DEST_DIR=$(jq -r '.settings.destination_directory' "$CONFIG_FILE")
DB_USER=$(jq -r '.settings.db_user' "$CONFIG_FILE")
DB_PASS=$(jq -r '.settings.db_password' "$CONFIG_FILE")
RCLONE_REMOTE=$(jq -r '.settings.rclone_remote' "$CONFIG_FILE")
RCLONE_PATH=$(jq -r '.settings.rclone_path' "$CONFIG_FILE")

mkdir -p "$DEST_DIR"
TIMESTAMP=$(date +%Y-%m-%d-%H%M%S)

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
        rclone move "$local_file" "$RCLONE_REMOTE:$RCLONE_PATH/$PROJECT_NAME"
    fi

    rm -rf "$STAGING_DIR"
done