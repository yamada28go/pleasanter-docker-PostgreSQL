#!/bin/bash

# ---- ---- ----
# S3に自動バックアップするShellコマンド

export PATH=$PATH:/usr/local/bin/aws

# バックアップ先ディレクトリ
SAVEPATH_BASE='/var/db_backup'

# AWS設定が存在したら処理を行う
AWS_CONFIG='/root/.aws/config'

# --- 処理用関数

# S3 同期用関数
do_s3_sync () {

  #S3の設定が確認できた場合
  echo "start S3 Sync"

  #同期処理時に無くなったファイルの情報まで同期するか確認
  if "$2" ; then
    echo "delete mode"
    readonly local SYNC_Delete=--delete
  else
    echo "not delete mode"
    readonly local SYNC_Delete=
  fi

  #保存用のパスを設定
  readonly local S3_PATH=s3://${S3_TARGET_BUCKET_NAME}/${S3_TARGET_DIRECTORY_NAME}/$1

  #S3への同期を開始 
  echo "path is " ${S3_PATH}
  flock -n /tmp/s3sync.lock /usr/local/bin/aws s3 sync ${SYNC_Delete} $SAVEPATH_BASE/$1 ${S3_PATH} 
  echo "sync end!"

}

#--- メイン実行部

# 同期実行中ならば同期処理は実行しない
exec 10>/tmp/$(basename $0 .sh).lock
flock -n 10
if [ $? -ne 0 ]; then
    echo "Sync is already executed! Not Start S3 Sync Sync."
    exit 1
fi

# import Setting Files
source /root/.aws/S3Config.sh

# 同期処理を開始
echo "Start S3 Sync Sync."
echo $1
echo $2
do_s3_sync $1 $2
