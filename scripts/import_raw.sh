#!/usr/bin/env bash
#
# import_raw.sh — Download and import raw wilayah data into SQLite
#
# Downloads the wilayah.sql dump from cahyadsn/wilayah, cleans MySQL-specific
# syntax, and imports it into a local SQLite database for further processing.
#
# Usage: bash scripts/import_raw.sh
#
# Output:
#   data/raw/wilayah.sql         — Original download
#   data/raw/wilayah.cleaned.sql — Cleaned SQL (MySQL syntax removed)
#   data/raw/raw_regions.db      — SQLite database with raw data
#
set -euo pipefail

SQL_URL="https://raw.githubusercontent.com/cahyadsn/wilayah/refs/heads/master/db/wilayah.sql"
DATA_DIR="data/raw"
SQL_FILE="$DATA_DIR/wilayah.sql"
CLEAN_FILE="$DATA_DIR/wilayah.cleaned.sql"
RAW_DB="$DATA_DIR/raw_regions.db"

log() { echo "=== $1"; }

prepare_directory() {
  log "[1/5] Creating directory: $DATA_DIR"
  mkdir -p "$DATA_DIR"
}

download_source() {
  log "[2/5] Downloading wilayah.sql from GitHub..."
  curl -# -L -o "$SQL_FILE" "$SQL_URL"
}

normalize_line_endings() {
  log "[3/5] Normalizing line endings..."
  if command -v dos2unix >/dev/null 2>&1; then
    dos2unix "$SQL_FILE" >/dev/null
  else
    sed -i 's/\r$//' "$SQL_FILE"
  fi
}

clean_mysql_syntax() {
  log "[4/5] Cleaning MySQL-specific syntax..."
  perl -0777 -pe '
    s/`//g;
    s/^\s*CREATE DATABASE.*?;\n//gmi;
    s/^\s*USE\s+\S+;\n//gmi;
    s/\)\s*ENGINE=[^;]+;/);/gi;
    s/DEFAULT CHARSET=[^;]+;//gi;
    s/AUTO_INCREMENT/AUTOINCREMENT/gi;
    s/\bUNSIGNED\b//gi;
    s/\bVARCHAR\(\d+\)/TEXT/gi;
    s/\bINT\(\d+\)/INTEGER/gi;
    s/LOCK TABLES.*?UNLOCK TABLES;//gis;
    s/\/\*\![0-9]+.*?\*\///gs;
  ' "$SQL_FILE" > "$CLEAN_FILE"
}

import_into_sqlite() {
  log "[5/5] Importing into SQLite..."
  rm -f "$RAW_DB"
  sqlite3 "$RAW_DB" < "$CLEAN_FILE"

  local table_count
  table_count=$(sqlite3 "$RAW_DB" "SELECT COUNT(*) FROM sqlite_master WHERE type='table';")
  log "Imported $table_count tables into $RAW_DB"
}

main() {
  prepare_directory
  download_source
  normalize_line_endings
  clean_mysql_syntax
  import_into_sqlite

  log "Done."
  echo "Output:"
  echo "  Original  : $SQL_FILE"
  echo "  Cleaned   : $CLEAN_FILE"
  echo "  SQLite DB : $RAW_DB"
}

main