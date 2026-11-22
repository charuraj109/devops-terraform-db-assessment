#!/usr/bin/env bash
# Creates a timestamped custom-format pg_dump in ./backups
set -euo pipefail
cd "$(dirname "$0")/.."

DB_USER="${DB_USER:-app}"
DB_NAME="${DB_NAME:-appdb}"
mkdir -p backups

OUT="backups/${DB_NAME}_$(date +%Y%m%d_%H%M%S).dump"
TMP="${OUT}.partial"

echo "Backing up '${DB_NAME}' -> ${OUT}"
docker compose exec -T db pg_dump -U "$DB_USER" -d "$DB_NAME" -Fc > "$TMP"
mv "$TMP" "$OUT"
echo "Backup complete: ${OUT} ($(du -h "$OUT" | cut -f1))"
