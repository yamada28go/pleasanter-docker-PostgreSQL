#!/bin/bash

# ---- ---- ----
# S3に自動バックアップするShellコマンド

export PATH=$PATH:/usr/local/bin/aws

# バックアップ先ディレクトリ
SAVEPATH_BASE='/var/db_backup'

# AWS設定が存在したら処理を行う
AWS_CONFIG='/root/.aws/config'

if [ -e $AWS_CONFIG ]; then

  echo "start new S3 backup!"

  source /root/.aws/S3Config.sh

  #S3の設定が確認できた場合
  flock -n /tmp/s3sync.lock /usr/local/bin/aws s3 sync $SAVEPATH_BASE s3://${S3_TARGET_BUCKET_NAME}/${S3_TARGET_DIRECTORY_NAME} --delete

fi


