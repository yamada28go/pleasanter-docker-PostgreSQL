#!/bin/bash

SCRIPT_DIR=$(
	cd $(dirname $0)
	pwd
)
source ${SCRIPT_DIR}/common.sh
source ${SCRIPT_DIR}/pg_rman_env.sh

# ローカルにバックアップファイルを残しておく日数
PERIOD='+2'

# バックアップ先ディレクトリ
SAVEPATH_BASE='/var/db_backup/dumpall'
# 日付
DATE=$(date '+%Y%m%d-%H%M%S')
# 先頭文字
PREFIX='postgres-'
# 拡張子
EXT='.sql'

#バックアップディレクトリ作成
SAVEPATH=$SAVEPATH_BASE/$(date '+%Y%m')/
log_info "pg_dumpall backup started. host=${DB_HOST} port=${DB_PORT} user=${DB_USER} savepath=${SAVEPATH}"
mkdir -p $SAVEPATH

# バックアップ実行
BACKUP_FILE_NAME=$PREFIX$DATE$EXT
BACKUP_FILE=$SAVEPATH$PREFIX$DATE$EXT
log_info "Creating dump archive: ${BACKUP_FILE}.7z"
time nice -n 19 pg_dumpall -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" | nice -n 19 7z a -mx=3 -mhe=on -p"$ZIP_PASSWORD" -si"$BACKUP_FILE_NAME" "$BACKUP_FILE.7z"

# 保存期間が過ぎたファイルの削除
log_info "Deleting old dump files. retention=${PERIOD} base=${SAVEPATH_BASE}"
find $SAVEPATH_BASE -type f -daystart -mtime $PERIOD -exec rm {} \;

# 空になったディレクトリを消去
log_info "Removing empty directories under ${SAVEPATH_BASE}"
find $SAVEPATH_BASE -type d -empty -delete

# S3同期を行う
log_info "Starting optional S3 sync for dumpall"
source ${SCRIPT_DIR}/syncToS3.sh dumpall false
