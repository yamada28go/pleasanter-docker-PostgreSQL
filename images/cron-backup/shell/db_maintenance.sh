#!/bin/bash

SCRIPT_DIR=$(
	cd "$(dirname "$0")" || exit 1
	pwd
)
# shellcheck source=images/cron-backup/shell/common.sh
source "${SCRIPT_DIR}/common.sh"
# shellcheck source=images/cron-backup/shell/pg_rman_env.sh
source "${SCRIPT_DIR}/pg_rman_env.sh"

# DBをメンテナンスする
log_info "DB maintenance started. host=${DB_HOST} port=${DB_PORT} db=${DB_NAME} user=${DB_USER}"
log_info "Running vacuumdb"
vacuumdb -v -z -a -U "$DB_USER" -h "$DB_HOST" -p "$DB_PORT"
log_info "Running reindexdb"
reindexdb --concurrently -v -d "$DB_NAME" -U "$DB_USER" -h "$DB_HOST" -p "$DB_PORT"
log_info "DB maintenance completed"
