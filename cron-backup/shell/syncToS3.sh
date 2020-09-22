#!/bin/bash

# ---- ---- ----
# S3に自動バックアップするShellコマンド

export PATH=$PATH:/usr/local/bin/aws

# バックアップ先ディレクトリ
SAVEPATH_BASE='/var/db_backup'

# AWS設定が存在したら処理を行う
AWS_CONFIG='/root/.aws/config'


# --- 一時ディレクトリ

# 一時ディレクトリを作成 (Pathを変数に代入しておく)
TempDir=$(mktemp -d)

# スクリプト終了時に一時ディレクトリを削除
trap 'rm -rf $TempDir' EXIT

# --- 処理用関数

# S3 同期用関数
do_s3_sync () {

  is_safe=$1

  #S3の設定が確認できた場合
  echo "start S3 Sync"

  if "${is_safe}" ; then
    echo "safe mode"
    echo 'safe-mode' >> ${SAVEPATH_BASE}/S3SyncLog.txt
    readonly local S3_PATH=s3://${S3_TARGET_BUCKET_NAME}/${S3_TARGET_DIRECTORY_NAME}-safe
  else
    echo "not safe mode"
    readonly local S3_PATH=s3://${S3_TARGET_BUCKET_NAME}/${S3_TARGET_DIRECTORY_NAME}
  fi

  #S3 同期ログに同期記録を追加
  echo `date +%Y%m%d_%H-%M-%S` >> ${SAVEPATH_BASE}/S3SyncLog.txt

  echo "path is " ${S3_PATH}
  flock -n /tmp/s3sync.lock /usr/local/bin/aws s3 sync $SAVEPATH_BASE ${S3_PATH} --delete
  echo "sync end!"

}

# --- 主関数

if [ -e $AWS_CONFIG ]; then

  echo "start new S3 backup!"

  # 設定ファイルを読み込み
  source /root/.aws/S3Config.sh

  S3Files=`/usr/local/bin/aws s3 ls s3://${S3_TARGET_BUCKET_NAME}/${S3_TARGET_DIRECTORY_NAME} --recursive --human | wc -l`
  LocalFiles=`find $SAVEPATH_BASE -type f | wc -l`

  # 処理対象の情報を記録
  echo "S3Files : " ${S3Files}
  echo "LocalFiles : " ${LocalFiles}
    
  # S3のデータ件数が1件 or 0件だったら
  # 初期状態扱いとする
  if [ "${S3Files}" == "0" -o  "${S3Files}" == "1" ]; then
    # S3への初期同期状態

    echo "On initial"
    do_s3_sync "false"

  else
    # S3への追加同期状態
  
    # S3パスからダウンロードログを取得する
    /usr/local/bin/aws s3 cp s3://${S3_TARGET_BUCKET_NAME}/${S3_TARGET_DIRECTORY_NAME}/S3SyncLog.txt ${TempDir}/

    #ファイルが一致するか比較する
    diff ${TempDir}/S3SyncLog.txt ${SAVEPATH_BASE}/S3SyncLog.txt

    ret=$?

    if [ $ret -eq 0 ] ;then
      # S3 Syncログファイルが一致するので通常モードでのバックアップ
      echo "log dir has no problem start additional sync mode"
      do_s3_sync "false"

    else

      # S3 Syncログファイルが一致しないのでsafeパスに同期する
      echo "log dir has problem start safe sync mode"
      do_s3_sync "true"

    fi
  
  fi

 fi


