#!/bin/bash

BASE_DIR=$(dirname "$(readlink -f "$0")")
CONFIG_FILE="$BASE_DIR/config.json"

if ! command -v jq &> /dev/null || ! command -v rclone &> /dev/null; then
    echo "[$(date)] Error: jq atau rclone tidak ditemukan."
    exit 1
fi

if [ ! -f "$CONFIG_FILE" ]; then
    echo "[$(date)] Error: File konfigurasi tidak ditemukan di $CONFIG_FILE"
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

echo "=========================================================="
echo "STARTING BACKUP PROCESS: $TIMESTAMP"
echo "=========================================================="

jq -c '.items[]' "$CONFIG_FILE" | while read -r item; do
    PROJECT_NAME=$(echo "$item" | jq -r '.name')
    PROJECT_PATH=$(echo "$item" | jq -r '.path')
    DB_NAME=$(echo "$item" | jq -r '.db_name // ""')

    echo "[Project: $PROJECT_NAME] Memulai proses..."

    mapfile -t FILES_TO_BACKUP < <(echo "$item" | jq -r '.files[]')

    if [ ! -d "$PROJECT_PATH" ]; then
        echo "[Project: $PROJECT_NAME] SKIPPED: Path $PROJECT_PATH tidak ditemukan."
        continue
    fi

    STAGING_DIR="$DEST_DIR/staging_${PROJECT_NAME}_${TIMESTAMP}"
    mkdir -p "$STAGING_DIR"

    if [ -n "$DB_NAME" ]; then
        echo "[Project: $PROJECT_NAME] Dumping database: $DB_NAME..."
        export MYSQL_PWD="$DB_PASS"
        if mysqldump -u"$DB_USER" "$DB_NAME" > "$STAGING_DIR/database_dump.sql" 2>/dev/null; then
            echo "[Project: $PROJECT_NAME] Database dump berhasil."
        else
            echo "[Project: $PROJECT_NAME] ERROR: Database dump gagal."
        fi
        unset MYSQL_PWD
    fi

    if [ ${#FILES_TO_BACKUP[@]} -gt 0 ]; then
        echo "[Project: $PROJECT_NAME] Menyalin file proyek..."
        for file_item in "${FILES_TO_BACKUP[@]}"; do
            if [ -e "$PROJECT_PATH/$file_item" ]; then
                cp -a "$PROJECT_PATH/$file_item" "$STAGING_DIR/"
                echo "  -> $file_item berhasil disalin."
            fi
        done
    fi

    backup_filename="backup-${PROJECT_NAME}-${TIMESTAMP}.tar.gz"
    local_file="$DEST_DIR/$backup_filename"
    
    echo "[Project: $PROJECT_NAME] Membuat arsip: $backup_filename..."
    if tar -czf "$local_file" -C "$STAGING_DIR" .; then
        echo "[Project: $PROJECT_NAME] Arsip berhasil dibuat."
    else
        echo "[Project: $PROJECT_NAME] ERROR: Pembuatan arsip gagal."
    fi

    if [ -f "$local_file" ]; then
        echo "[Project: $PROJECT_NAME] Mengunggah ke cloud ($RCLONE_REMOTE)..."
        if rclone move "$local_file" "$RCLONE_REMOTE:$RCLONE_PATH/$PROJECT_NAME"; then
            echo "[Project: $PROJECT_NAME] Upload berhasil dan file lokal dihapus."
        else
            echo "[Project: $PROJECT_NAME] ERROR: Gagal mengunggah ke cloud."
        fi
    fi

    rm -rf "$STAGING_DIR"
    echo "[Project: $PROJECT_NAME] Selesai."
    echo "----------------------------------------------------------"
done

echo "=========================================================="
echo "ALL BACKUP PROCESSES COMPLETED: $(date)"
echo "=========================================================="