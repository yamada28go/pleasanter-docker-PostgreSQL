#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

PRETTIER_FILES=(
	readme.md
	docker-compose.yml
	docker-compose.https-portal.yml
	.markdownlint.json
	.prettierrc.json
	.yamllint.yml
)

OPTIONAL_PRETTIER_FILES=(
	docker-compose.monitoring.yml
	monitoring/prometheus/prometheus.yml
	monitoring/grafana/provisioning/datasources/prometheus.yml
)

require_command() {
	if ! command -v "$1" >/dev/null 2>&1; then
		echo "Required command not found: $1" >&2
		exit 1
	fi
}

run_node_tool() {
	local tool="$1"
	shift

	if [[ -x "${ROOT_DIR}/node_modules/.bin/${tool}" ]]; then
		"${ROOT_DIR}/node_modules/.bin/${tool}" "$@"
		return
	fi

	require_command "$tool"
	"$tool" "$@"
}

append_existing_files() {
	local path
	for path in "$@"; do
		if [[ -f "${path}" ]]; then
			PRETTIER_FILES+=("${path}")
		fi
	done
}

require_command shfmt

echo "[format] shfmt"
shfmt -w \
	images/cron-backup/shell/common.sh \
	images/cron-backup/shell/db_maintenance.sh \
	images/cron-backup/shell/pg_dumpall.sh \
	images/cron-backup/shell/pg_rman.sh \
	images/cron-backup/shell/pg_rman_env.sh \
	images/cron-backup/shell/sync_to_s3.sh \
	images/cron-backup/shell/syslogs_maintenance/syslogs_maintenance.sh \
	images/postgres-db/docker-entrypoint-wrapper.sh \
	scripts/lint.sh \
	scripts/format.sh

echo "[format] prettier"
append_existing_files "${OPTIONAL_PRETTIER_FILES[@]}"
PRETTIER_FILES+=(doc/*.md)
run_node_tool prettier --write "${PRETTIER_FILES[@]}"

echo "[format] done"
