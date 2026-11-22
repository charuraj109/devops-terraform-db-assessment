#!/usr/bin/env bash
# Shows EXPLAIN ANALYZE for the target query without and with the covering index.
set -euo pipefail
cd "$(dirname "$0")/.."
P="docker compose exec -T db psql -U ${DB_USER:-app} -d ${DB_NAME:-appdb}"

echo "=== BEFORE (index dropped) ==="
$P -c "DROP INDEX IF EXISTS idx_hotel_bookings_city_created_cover;" -c "VACUUM ANALYZE hotel_bookings;"
$P < db/optimize_query.sql

echo; echo "=== AFTER (covering index) ==="
$P -c "CREATE INDEX idx_hotel_bookings_city_created_cover ON hotel_bookings (city, created_at) INCLUDE (org_id, status, amount);" -c "VACUUM ANALYZE hotel_bookings;"
$P < db/optimize_query.sql
