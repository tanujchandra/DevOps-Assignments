#!/usr/bin/env bash
# Restores a backup into a FRESH database and verifies it against the source.
#   ./scripts/restore.sh                      # newest file in ./backups
#   ./scripts/restore.sh backups/xyz.sql.gz   # a specific file
#   RESTORE_DB=my_copy ./scripts/restore.sh   # custom target name
set -euo pipefail
# shellcheck source=scripts/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

require_db

FILE="${1:-}"
if [ -z "$FILE" ]; then
  FILE="$(ls -1t "$BACKUP_DIR"/*.sql.gz 2>/dev/null | head -n1 || true)"
fi
if [ -z "$FILE" ] || [ ! -f "$FILE" ]; then
  echo "ERROR: no backup file found. Run ./scripts/backup.sh first." >&2
  exit 1
fi
gzip -t "$FILE"

RESTORE_DB="${RESTORE_DB:-${DB_NAME}_restored}"
if [ "$RESTORE_DB" = "$DB_NAME" ]; then
  echo "ERROR: RESTORE_DB must differ from the source database ('$DB_NAME')." >&2
  exit 1
fi

echo "==> Backup file : $FILE"
echo "==> Target DB   : $RESTORE_DB (dropped and recreated)"

db psql -U "$DB_USER" -d postgres -v ON_ERROR_STOP=1 -c "DROP DATABASE IF EXISTS \"$RESTORE_DB\" WITH (FORCE);"
db psql -U "$DB_USER" -d postgres -v ON_ERROR_STOP=1 -c "CREATE DATABASE \"$RESTORE_DB\";"

echo "==> Restoring ..."
gunzip -c "$FILE" | db psql -U "$DB_USER" -d "$RESTORE_DB" -v ON_ERROR_STOP=1 -q >/dev/null

echo "==> Verifying restored data against '$DB_NAME' ..."
FAILED=0

check() { # name, source value, restored value
  # an empty value means the query itself failed -> never treat that as a pass
  if [ -n "$2" ] && [ "$2" = "$3" ]; then
    printf '  PASS  %-34s %s\n' "$1" "$3"
  else
    printf '  FAIL  %-34s source=%s restored=%s\n' "$1" "$2" "$3"
    FAILED=1
  fi
}

ROWS_SQL_BOOKINGS="SELECT count(*) FROM hotel_bookings"
ROWS_SQL_EVENTS="SELECT count(*) FROM booking_events"
SUM_SQL_BOOKINGS="SELECT md5(string_agg(t::text, '|' ORDER BY id)) FROM hotel_bookings t"
SUM_SQL_EVENTS="SELECT md5(string_agg(t::text, '|' ORDER BY id)) FROM booking_events t"
IDX_SQL="SELECT count(*) FROM pg_indexes WHERE indexname = 'idx_hotel_bookings_city_created_at'"
# Use ONE fixed timestamp for both databases so the 30-day window is identical
NOW_TS="$(sql_value "$DB_NAME" "SELECT now()")"
REPORT_SQL="SELECT md5(string_agg(x::text, '|' ORDER BY x::text)) FROM (
  SELECT org_id, status, COUNT(*), SUM(amount) FROM hotel_bookings
  WHERE city = 'delhi' AND created_at >= '$NOW_TS'::timestamptz - INTERVAL '30 days'
  GROUP BY org_id, status) x"

check "hotel_bookings row count"   "$(sql_value "$DB_NAME" "$ROWS_SQL_BOOKINGS")" "$(sql_value "$RESTORE_DB" "$ROWS_SQL_BOOKINGS")"
check "booking_events row count"   "$(sql_value "$DB_NAME" "$ROWS_SQL_EVENTS")"   "$(sql_value "$RESTORE_DB" "$ROWS_SQL_EVENTS")"
check "hotel_bookings content md5" "$(sql_value "$DB_NAME" "$SUM_SQL_BOOKINGS")"   "$(sql_value "$RESTORE_DB" "$SUM_SQL_BOOKINGS")"
check "booking_events content md5" "$(sql_value "$DB_NAME" "$SUM_SQL_EVENTS")"     "$(sql_value "$RESTORE_DB" "$SUM_SQL_EVENTS")"
check "city/created_at index exists" "$(sql_value "$DB_NAME" "$IDX_SQL")"          "$(sql_value "$RESTORE_DB" "$IDX_SQL")"
check "delhi report query result"  "$(sql_value "$DB_NAME" "$REPORT_SQL")"         "$(sql_value "$RESTORE_DB" "$REPORT_SQL")"

if [ "$FAILED" -ne 0 ]; then
  echo "==> RESTORE VERIFICATION FAILED" >&2
  exit 1
fi
echo "==> Restore verified OK. Inspect it with:"
echo "    docker compose exec db psql -U $DB_USER -d $RESTORE_DB"
