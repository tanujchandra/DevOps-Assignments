#!/usr/bin/env bash
# Creates a timestamped, compressed logical backup of the local database.
#   ./scripts/backup.sh
# Output: backups/<db>_<YYYYmmdd_HHMMSS>.sql.gz
set -euo pipefail
# shellcheck source=scripts/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

require_db
mkdir -p "$BACKUP_DIR"

TS="$(date +%Y%m%d_%H%M%S)"
FILE="$BACKUP_DIR/${DB_NAME}_${TS}.sql.gz"

echo "==> Backing up database '$DB_NAME' ..."
# --clean --if-exists : the dump can be replayed onto an existing DB too
# --no-owner/privileges: portable between different DB users
if ! db pg_dump -U "$DB_USER" -d "$DB_NAME" --no-owner --no-privileges --clean --if-exists \
      | gzip > "$FILE.tmp"; then
  rm -f "$FILE.tmp"
  echo "ERROR: pg_dump failed" >&2
  exit 1
fi

# Never keep a corrupt/empty file under the final name
gzip -t "$FILE.tmp"
mv "$FILE.tmp" "$FILE"

echo "==> Backup created: $FILE ($(du -h "$FILE" | cut -f1))"
