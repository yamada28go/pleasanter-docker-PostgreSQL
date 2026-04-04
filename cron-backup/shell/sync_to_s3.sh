#!/bin/bash

# ---- ---- ----
# S3に自動バックアップするShellコマンド

SCRIPT_DIR=$(
	cd "$(dirname "$0")" || exit 1
	pwd
)
# shellcheck source=cron-backup/shell/common.sh
source "${SCRIPT_DIR}/common.sh"

export PATH="$PATH:/usr/local/bin/aws"

# バックアップ先ディレクトリ
SAVEPATH_BASE='/var/db_backup'

is_sourced() {
	[[ "${BASH_SOURCE[0]}" != "$0" ]]
}

finish_sync_script() {
	local exit_code="$1"

	if is_sourced; then
		return "${exit_code}"
	fi

	exit "${exit_code}"
}

require_env() {
	local var_name="$1"

	if [ -z "${!var_name:-}" ]; then
		log_error "Required environment variable is not set: ${var_name}"
		return 1
	fi
}

# --- 処理用関数

# S3 同期用関数
do_s3_sync() {
	local sync_target="$1"
	local delete_mode="$2"
	local sync_delete=""
	local s3_path="s3://${S3_TARGET_BUCKET_NAME}/${S3_TARGET_DIRECTORY_NAME}/${sync_target}"

	#S3の設定が確認できた場合
	log_info "Starting S3 sync for target=${sync_target}"

	#同期処理時に無くなったファイルの情報まで同期するか確認
	if [[ "${delete_mode}" == "true" ]]; then
		log_info "S3 sync delete mode enabled"
		sync_delete="--delete"
	else
		log_info "S3 sync delete mode disabled"
	fi

	#S3への同期を開始
	log_info "S3 destination path: ${s3_path}"
	flock -n /tmp/s3sync.lock /usr/local/bin/aws s3 sync ${sync_delete:+$sync_delete} "${SAVEPATH_BASE}/${sync_target}" "${s3_path}"
	log_info "S3 sync finished"

}

if [ -z "${ENABLE_S3_BACKUP:-}" ]; then
	log_warn "ENABLE_S3_BACKUP is not set. skip S3 sync"
	finish_sync_script 0
fi

log_info "S3 backup flow started"

#--- メイン実行部

# 同期実行中ならば同期処理は実行しない
exec 10>"/tmp/$(basename "$0" .sh).lock"
if ! flock -n 10; then
	log_warn "Another S3 sync is already running. skip"
	finish_sync_script 0
fi

if ! command -v aws >/dev/null 2>&1; then
	log_error "aws command not found"
	finish_sync_script 1
fi

for required_var in AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY S3_TARGET_BUCKET_NAME S3_TARGET_DIRECTORY_NAME; do
	if ! require_env "${required_var}"; then
		finish_sync_script 1
	fi
done

if [ -z "${AWS_DEFAULT_REGION:-${AWS_REGION:-}}" ]; then
	log_error "Required environment variable is not set: AWS_DEFAULT_REGION or AWS_REGION"
	finish_sync_script 1
fi

# 同期処理を開始
log_info "Invoking S3 sync. category=$1 delete_mode=$2"
do_s3_sync "$1" "$2"
