#!/bin/bash

# --- Cukup edit baris ini ---
CONFIG_FILE="/root/backup/scripts/backup_config.json"

# --- Validasi Awal ---
if ! command -v jq &> /dev/null; then
    echo "Error: 'jq' tidak ditemukan. Mohon install terlebih dahulu."
    exit 1
fi
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: File konfigurasi '$CONFIG_FILE' tidak ditemukan."
    exit 1
fi

# --- Membaca Konfigurasi Global dari JSON ---
DEST_DIR=$(jq -r '.settings.destination_directory' "$CONFIG_FILE")
DB_USER=$(jq -r '.settings.db_user' "$CONFIG_FILE")
DB_PASS=$(jq -r '.settings.db_password' "$CONFIG_FILE")

# --- Proses Utama ---
mkdir -p "$DEST_DIR"
TIMESTAMP=$(date +%Y-%m-%d-%H%M%S)

echo "### Memulai Backup Menggunakan Konfigurasi dari $CONFIG_FILE ###"
jq -c '.items[]' "$CONFIG_FILE" | while read -r item; do
    PROJECT_NAME=$(echo "$item" | jq -r '.name')
    PROJECT_PATH=$(echo "$item" | jq -r '.path')
    DB_NAME=$(echo "$item" | jq -r '.db_name // ""')

    mapfile -t FILES_TO_BACKUP < <(echo "$item" | jq -r '.files[]')

    if [ ! -d "$PROJECT_PATH" ]; then
        echo "Peringatan: Path '$PROJECT_PATH' untuk item '$PROJECT_NAME' tidak ditemukan, dilewati."
        continue
    fi

    # --- 1. Persiapan Staging ---
    # Membuat direktori sementara yang unik untuk menampung semua file backup proyek ini
    STAGING_DIR="$DEST_DIR/staging_${PROJECT_NAME}_${TIMESTAMP}"
    mkdir -p "$STAGING_DIR"

    echo "Memproses: $PROJECT_NAME..."

    # --- 2. Backup Database ke Staging (jika ada) ---
    if [ -n "$DB_NAME" ]; then
        echo "  -> Melakukan dump database '$DB_NAME'..."
        mysqldump -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" > "$STAGING_DIR/database_dump.sql"
        if [ $? -ne 0 ]; then
            echo "  Error: Gagal melakukan dump database '$DB_NAME'."
        fi
    fi

    # --- 3. Salin File Proyek ke Staging ---
    if [ ${#FILES_TO_BACKUP[@]} -gt 0 ]; then
        echo "  -> Menyalin file proyek..."
        # Loop untuk setiap file/direktori dan salin ke staging
        for file_item in "${FILES_TO_BACKUP[@]}"; do
            # Menggunakan cp -a untuk menjaga perizinan dan menyalin direktori secara rekursif
            cp -a "$PROJECT_PATH/$file_item" "$STAGING_DIR/"
        done
    fi

    # --- 4. Buat Arsip Tunggal dari Direktori Staging ---
    backup_filename="backup-${PROJECT_NAME}-${TIMESTAMP}.tar.gz"
    dest_file="$DEST_DIR/$backup_filename"
    
    echo "  -> Membuat arsip tunggal..."
    # -C akan membuat isi dari STAGING_DIR menjadi root di dalam arsip
    tar -czf "$dest_file" -C "$STAGING_DIR" .

    if [ $? -eq 0 ]; then
        echo "Backup gabungan selesai: $dest_file"
    else
        echo "Error: Gagal membuat arsip untuk '$PROJECT_NAME'."
    fi

    # --- 5. Hapus Direktori Staging ---
    rm -rf "$STAGING_DIR"
done

echo "Semua proses backup telah selesai."
