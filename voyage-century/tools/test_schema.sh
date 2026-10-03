#!/usr/bin/env bash
# Spielt database/schema.sql in eine Wegwerf-PostgreSQL-Instanz ein und führt
# database/smoke_test.sql aus. Braucht lokale PostgreSQL-Binaries (initdb, pg_ctl, psql).
#
#   tools/test_schema.sh
#
# Läuft das Skript als root, werden die Server-Befehle als Benutzer "postgres" ausgeführt.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PG_BIN="${PG_BIN:-$(dirname "$(command -v initdb 2>/dev/null || ls -d /usr/lib/postgresql/*/bin/initdb | tail -1)")}"
WORK="$(mktemp -d)"
PORT="${PGTEST_PORT:-55432}"

run() {
    if [ "$(id -u)" -eq 0 ]; then
        su postgres -s /bin/bash -c "$(printf '%q ' "$@")"
    else
        "$@"
    fi
}

cleanup() {
    run "$PG_BIN/pg_ctl" -D "$WORK/data" -m immediate stop >/dev/null 2>&1 || true
    rm -rf "$WORK"
}
trap cleanup EXIT

[ "$(id -u)" -eq 0 ] && chown postgres "$WORK"
cp "$ROOT/database/schema.sql" "$ROOT/database/smoke_test.sql" "$WORK/"
[ "$(id -u)" -eq 0 ] && chown postgres "$WORK"/*.sql

run "$PG_BIN/initdb" -D "$WORK/data" -U postgres --auth=trust -E UTF8 >/dev/null
run "$PG_BIN/pg_ctl" -D "$WORK/data" -o "-p $PORT -k $WORK -c listen_addresses=''" -l "$WORK/pg.log" -w start >/dev/null

PSQL=("$PG_BIN/psql" -h "$WORK" -p "$PORT" -U postgres -v ON_ERROR_STOP=1 -q)
run "${PSQL[@]}" -d postgres -c "CREATE DATABASE vc_test"
run "${PSQL[@]}" -d vc_test -f "$WORK/schema.sql"
echo "Schema eingespielt: $(run "${PSQL[@]}" -d vc_test -tAc "SELECT count(*) FROM pg_tables WHERE schemaname = 'public'") Tabellen"
run "${PSQL[@]}" -d vc_test -f "$WORK/smoke_test.sql"
