#!/usr/bin/env bash

set -euo pipefail

ARCLOG_PATH="${POSTGRES_ARCLOG_PATH:-/var/lib/postgresql/arclog}"

# PostgreSQL が起動直後から WAL を archive できるよう、共有 volume の所有権を先に整える。
mkdir -p "${ARCLOG_PATH}"
chown postgres:postgres "${ARCLOG_PATH}"
chmod 700 "${ARCLOG_PATH}"

exec /usr/local/bin/docker-entrypoint.sh "$@"
