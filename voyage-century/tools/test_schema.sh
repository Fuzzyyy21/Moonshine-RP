#!/usr/bin/env bash
# Spielt alle Migrationen (database/migrations/V*.sql) und Seeds (database/seed/R__*.sql)
# per psql in eine frische Datenbank ein und führt database/smoke_test.sql aus.
# Unabhängig vom .NET-Migrator, damit das Schema für sich allein prüfbar bleibt.
#
#   tools/test_schema.sh
#
# Nutzt eine vorhandene Instanz über PGHOST/PGPORT/PGUSER, wenn VC_TEST_PG gesetzt ist,
# sonst eine Wegwerf-Instanz (tools/lib/pg_temp.sh).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=lib/pg_temp.sh
source "$ROOT/tools/lib/pg_temp.sh"
pg_temp_start

DB="vc_schema_test_$$"
PSQL=(psql -v ON_ERROR_STOP=1 -q -X)
"${PSQL[@]}" -d postgres -c "CREATE DATABASE $DB"
trap '"${PSQL[@]}" -d postgres -c "DROP DATABASE IF EXISTS $DB" >/dev/null 2>&1 || true; pg_temp_stop' EXIT

for f in "$ROOT"/database/migrations/V*.sql "$ROOT"/database/seed/R__*.sql; do
    [ -e "$f" ] || continue
    "${PSQL[@]}" -d "$DB" --single-transaction -f "$f"
    echo "angewendet: ${f#"$ROOT"/}"
done
echo "Tabellen: $("${PSQL[@]}" -d "$DB" -tAc "SELECT count(*) FROM pg_tables WHERE schemaname = 'public'")"
"${PSQL[@]}" -d "$DB" -f "$ROOT/database/smoke_test.sql"
