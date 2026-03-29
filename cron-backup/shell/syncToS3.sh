#!/bin/bash

# ---- ---- ----
# S3に自動バックアップするShellコマンド

SCRIPT_DIR=$(cd $(dirname $0); pwd)
source ${SCRIPT_DIR}/common.sh

export PATH=$PATH:/usr/local/bin/aws

# バックアップ先ディレクトリ
SAVEPATH_BASE='/var/db_backup'

# AWS設定が存在したら処理を行う
AWS_CONFIG='/root/.aws/config'

# --- 処理用関数

# S3 同期用関数
do_s3_sync () {

  #S3の設定が確認できた場合
  log_info "Starting S3 sync for target=$1"

  #同期処理時に無くなったファイルの情報まで同期するか確認
  if "$2" ; then
    log_info "S3 sync delete mode enabled"
    readonly local SYNC_Delete=--delete
  else
    log_info "S3 sync delete mode disabled"
    readonly local SYNC_Delete=
  fi

  #保存用のパスを設定
  readonly local S3_PATH=s3://${S3_TARGET_BUCKET_NAME}/${S3_TARGET_DIRECTORY_NAME}/$1

  #S3への同期を開始 
  log_info "S3 destination path: ${S3_PATH}"
  flock -n /tmp/s3sync.lock /usr/local/bin/aws s3 sync ${SYNC_Delete} $SAVEPATH_BASE/$1 ${S3_PATH} 
  log_info "S3 sync finished"

}

if [ -z $ENABLE_S3_BACKUP ]; then
  log_warn "ENABLE_S3_BACKUP is not set. skip S3 sync"
  exit -1
fi

log_info "S3 backup flow started"

#--- メイン実行部

# 同期実行中ならば同期処理は実行しない
exec 10>/tmp/$(basename $0 .sh).lock
flock -n 10
if [ $? -ne 0 ]; then
    log_warn "Another S3 sync is already running. skip"
    exit 1
fi

# import Setting Files
source /root/.aws/S3Config.sh

# 同期処理を開始
log_info "Invoking S3 sync. category=$1 delete_mode=$2"
do_s3_sync $1 $2
