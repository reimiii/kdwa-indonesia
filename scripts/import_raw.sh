#!/usr/bin/env bash
set -euo pipefail

SQL_URL="https://raw.githubusercontent.com/cahyadsn/wilayah/refs/heads/master/db/wilayah.sql"
DATA_DIR="data/raw"
SQL_FILE="$DATA_DIR/wilayah.sql"
CLEAN_FILE="$DATA_DIR/wilayah.cleaned.sql"
RAW_DB="$DATA_DIR/raw_regions.db"

echo "=== [1/6] Preparing directory..."
mkdir -p "$DATA_DIR"

echo "=== [2/6] Downloading wilayah.sql from GitHub..."
curl -# -L -o "$SQL_FILE" "$SQL_URL"

echo "=== [3/6] Normalizing line endings..."
if command -v dos2unix >/dev/null 2>&1; then
  dos2unix "$SQL_FILE" >/dev/null
else
  sed -i 's/\r$//' "$SQL_FILE"
fi

echo "=== [4/6] Cleaning MySQL-specific syntax..."
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

awk -v date="$(date '+%Y-%m-%d %H:%M:%S')" '
/\*\// && !done {
  print $0 "\n/* Edited by Hilmi AM on " date " */"
  done=1
  next
}
{ print }' "$CLEAN_FILE" > "${CLEAN_FILE}.tmp" && mv "${CLEAN_FILE}.tmp" "$CLEAN_FILE"

echo "=== [5/6] Importing into SQLite..."
rm -f "$RAW_DB"
sqlite3 "$RAW_DB" < "$CLEAN_FILE"

echo "=== [6/6] Verification: existing tables"
sqlite3 "$RAW_DB" "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name;" | head -n 10

echo "=== Done."
echo "Output SQLite: $RAW_DB"
echo "Cleaned SQL:   $CLEAN_FILE"
