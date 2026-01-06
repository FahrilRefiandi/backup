#!/bin/bash

BASE_DIR=$(dirname "$(readlink -f "$0")")
CONFIG_FILE="$BASE_DIR/config.json"

if ! command -v jq &> /dev/null || ! command -v rclone &> /dev/null; then
    exit 1
fi

if [ ! -f "$CONFIG_FILE" ]; then
    exit 1
fi

DEST_FOLDER=$(jq -r '.settings.destination_folder' "$CONFIG_FILE")
DEST_DIR="$BASE_DIR/$DEST_FOLDER"
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
        export MYSQL_PWD="$DB_PASS"
        mysqldump -u"$DB_USER" "$DB_NAME" > "$STAGING_DIR/database_dump.sql" 2>/dev/null
        unset MYSQL_PWD
    fi

    if [ ${#FILES_TO_BACKUP[@]} -gt 0 ]; then
        for file_item in "${FILES_TO_BACKUP[@]}"; do
            if [ -e "$PROJECT_PATH/$file_item" ]; then
                cp -a "$PROJECT_PATH/$file_item" "$STAGING_DIR/"
            fi
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