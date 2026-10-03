#!/usr/bin/env bash
# Baut das Backend und führt alle Tests gegen eine echte PostgreSQL aus.
# Ohne VC_TEST_PG wird eine Wegwerf-Instanz gestartet (tools/lib/pg_temp.sh).
#
#   tools/test_backend.sh [zusätzliche dotnet-test-Argumente]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=lib/pg_temp.sh
source "$ROOT/tools/lib/pg_temp.sh"
pg_temp_start

export DOTNET_CLI_TELEMETRY_OPTOUT=1 DOTNET_NOLOGO=1
dotnet test "$ROOT/backend/VoyageCentury.slnx" --logger "console;verbosity=normal" "$@"
