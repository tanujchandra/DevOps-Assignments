#!/usr/bin/env bash
# Shows the query plan WITHOUT and WITH the index (for the README / reviewers).
#   ./scripts/explain.sh
# The index is dropped inside a transaction that is rolled back, so nothing
# is changed permanently.
set -euo pipefail
# shellcheck source=scripts/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

require_db
QUERY="$(cat db/queries/dashboard_query.sql)"

db psql -U "$DB_USER" -d "$DB_NAME" -v ON_ERROR_STOP=1 <<SQL
\echo
\echo '===== WITHOUT idx_hotel_bookings_city_created_at ====='
BEGIN;
DROP INDEX idx_hotel_bookings_city_created_at;
EXPLAIN (ANALYZE, BUFFERS) $QUERY
ROLLBACK;

\echo
\echo '===== WITH idx_hotel_bookings_city_created_at ====='
EXPLAIN (ANALYZE, BUFFERS) $QUERY
SQL
