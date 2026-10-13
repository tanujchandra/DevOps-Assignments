#!/usr/bin/env bash
# Shared helpers, sourced by backup.sh / restore.sh / explain.sh.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# Optional .env (same file docker compose reads)
if [ -f .env ]; then
  set -a
  # shellcheck disable=SC1091
  . ./.env
  set +a
fi

DB_USER="${POSTGRES_USER:-app}"
DB_NAME="${POSTGRES_DB:-hotel}"
BACKUP_DIR="${BACKUP_DIR:-$ROOT_DIR/backups}"

# Run a command inside the running database container
db() {
  docker compose exec -T -e PGOPTIONS="-c client_min_messages=warning" db "$@"
}

# Run one SQL statement against database $1 and print only the value
sql_value() {
  db psql -U "$DB_USER" -d "$1" -v ON_ERROR_STOP=1 -tAc "$2"
}

require_db() {
  if ! db pg_isready -U "$DB_USER" -d "$DB_NAME" >/dev/null 2>&1; then
    echo "ERROR: database container is not running or not ready." >&2
    echo "       Start it with:  docker compose up -d" >&2
    exit 1
  fi
}
