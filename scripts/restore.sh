#!/usr/bin/env bash
# Restores a backup into a FRESH database (appdb_restore) and verifies row counts.
# Usage: ./scripts/restore.sh [backup_file]   (defaults to the newest file in ./backups)
set -euo pipefail
cd "$(dirname "$0")/.."

DB_USER="${DB_USER:-app}"
DB_NAME="${DB_NAME:-appdb}"
RESTORE_DB="${RESTORE_DB:-appdb_restore}"

BACKUP_FILE="${1:-$(ls -1t backups/*.dump 2>/dev/null | head -n1 || true)}"
if [ -z "$BACKUP_FILE" ] || [ ! -f "$BACKUP_FILE" ]; then
  echo "No backup file found. Run ./scripts/backup.sh first." >&2
  exit 1
fi

DC="docker compose exec -T db"
count() { $DC psql -U "$DB_USER" -d "$1" -tAc "SELECT count(*) FROM $2"; }
indexes() { $DC psql -U "$DB_USER" -d "$1" -tAc "SELECT count(*) FROM pg_indexes WHERE schemaname='public'"; }

echo "Restoring ${BACKUP_FILE} into fresh database '${RESTORE_DB}'"
$DC psql -U "$DB_USER" -d postgres -v ON_ERROR_STOP=1 -c "DROP DATABASE IF EXISTS \"${RESTORE_DB}\" WITH (FORCE);"
$DC psql -U "$DB_USER" -d postgres -v ON_ERROR_STOP=1 -c "CREATE DATABASE \"${RESTORE_DB}\";"
$DC pg_restore -U "$DB_USER" -d "$RESTORE_DB" --no-owner --exit-on-error < "$BACKUP_FILE"

echo
echo "Verification (source vs restored):"
STATUS=0
for t in hotel_bookings booking_events; do
  a=$(count "$DB_NAME" "$t"); b=$(count "$RESTORE_DB" "$t")
  if [ "$a" = "$b" ]; then r="OK"; else r="MISMATCH"; STATUS=1; fi
  printf "  %-16s source=%-8s restored=%-8s %s\n" "$t" "$a" "$b" "$r"
done
a=$(indexes "$DB_NAME"); b=$(indexes "$RESTORE_DB")
if [ "$a" = "$b" ]; then r="OK"; else r="MISMATCH"; STATUS=1; fi
printf "  %-16s source=%-8s restored=%-8s %s\n" "indexes" "$a" "$b" "$r"

[ "$STATUS" -eq 0 ] && echo "Restore verified successfully." || { echo "Restore verification FAILED." >&2; exit 1; }
