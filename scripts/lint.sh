#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

YAML_FILES=(
	docker-compose.yml
	docker-compose.https-portal.yml
)

OPTIONAL_YAML_FILES=(
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
			YAML_FILES+=("${path}")
		fi
	done
}

require_command docker
require_command hadolint
require_command shellcheck
require_command yamllint

echo "[lint] docker compose config"
docker compose config >/dev/null

if [[ -f docker-compose.monitoring.yml ]]; then
	echo "[lint] docker compose monitoring config"
	docker compose -f docker-compose.yml -f docker-compose.monitoring.yml config >/dev/null
fi

echo "[lint] hadolint"
hadolint images/cron-backup/Dockerfile

echo "[lint] shellcheck"
shellcheck -x \
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

echo "[lint] markdownlint"
run_node_tool markdownlint-cli2 \
	readme.md \
	"doc/**/*.md"

echo "[lint] yamllint"
append_existing_files "${OPTIONAL_YAML_FILES[@]}"
yamllint \
	"${YAML_FILES[@]}"

echo "[lint] done"
