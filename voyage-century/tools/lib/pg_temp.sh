# shellcheck shell=bash
# Stellt eine PostgreSQL-Instanz für Tests bereit.
#
#   source tools/lib/pg_temp.sh
#   pg_temp_start        # setzt VC_TEST_PG (Npgsql) und PGHOST/PGPORT/PGUSER (psql)
#
# Ist VC_TEST_PG bereits gesetzt (z. B. in CI mit Service-Container), wird nichts
# gestartet. Sonst wird eine Wegwerf-Instanz mit initdb in einem Temp-Ordner erzeugt
# und beim Beenden des aufrufenden Skripts wieder entfernt. Läuft das Skript als
# root, werden initdb und pg_ctl als Benutzer "postgres" ausgeführt.

_pg_run() {
    if [ "$(id -u)" -eq 0 ]; then
        su postgres -s /bin/bash -c "$(printf '%q ' "$@")"
    else
        "$@"
    fi
}

pg_temp_stop() {
    if [ -n "${_PG_TEMP_DIR:-}" ]; then
        _pg_run "$_PG_BIN/pg_ctl" -D "$_PG_TEMP_DIR/data" -m immediate stop >/dev/null 2>&1 || true
        rm -rf "$_PG_TEMP_DIR"
        _PG_TEMP_DIR=""
    fi
}

pg_temp_start() {
    if [ -n "${VC_TEST_PG:-}" ]; then
        return 0
    fi
    _PG_BIN="${PG_BIN:-$(dirname "$(command -v initdb 2>/dev/null || ls -d /usr/lib/postgresql/*/bin/initdb | tail -1)")}"
    _PG_TEMP_DIR="$(mktemp -d)"
    local port="${PGTEST_PORT:-55432}"
    [ "$(id -u)" -eq 0 ] && chown postgres "$_PG_TEMP_DIR"
    trap pg_temp_stop EXIT

    _pg_run "$_PG_BIN/initdb" -D "$_PG_TEMP_DIR/data" -U postgres --auth=trust -E UTF8 >/dev/null
    _pg_run "$_PG_BIN/pg_ctl" -D "$_PG_TEMP_DIR/data" \
        -o "-p $port -k $_PG_TEMP_DIR -c listen_addresses=''" -l "$_PG_TEMP_DIR/pg.log" -w start >/dev/null

    export PGHOST="$_PG_TEMP_DIR" PGPORT="$port" PGUSER=postgres
    export VC_TEST_PG="Host=$_PG_TEMP_DIR;Port=$port;Username=postgres"
}
