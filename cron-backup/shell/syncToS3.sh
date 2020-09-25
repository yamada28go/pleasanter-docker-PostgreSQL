#!/bin/bash

# ---- ---- ----
# S3に自動バックアップするShellコマンド

export PATH=$PATH:/usr/local/bin/aws

# バックアップ先ディレクトリ
SAVEPATH_BASE='/var/db_backup'

# AWS設定が存在したら処理を行う
AWS_CONFIG='/root/.aws/config'

# S3同期管理ログファイル名
S3SyncLogFileName=${SAVEPATH_BASE}'/S3SyncLog.txt'

# バックアップ済みファイルのハッシュ一覧
FilesHashFileName='BackupFiles.sha256'
FilesHashFileNamePath=${SAVEPATH_BASE}'/'${FilesHashFileName}

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
    do_add_synclog 'safe-mode'
    readonly local S3_PATH=s3://${S3_TARGET_BUCKET_NAME}/${S3_TARGET_DIRECTORY_NAME}-safe
  else
    echo "not safe mode"
    readonly local S3_PATH=s3://${S3_TARGET_BUCKET_NAME}/${S3_TARGET_DIRECTORY_NAME}
  fi

  #S3 同期ログに同期記録を追加
  do_add_synclog `date +%Y%m%d_%H-%M-%S`

  #バックアップ済みのディレクトリハッシュを生成
  time nice -n 19 find $SAVEPATH_BASE -type f -exec sha256sum {} \; > ${FilesHashFileNamePath}
  time nice -n 19 7z a -mx=9 ${FilesHashFileNamePath}.7z ${FilesHashFileNamePath}
  rm -f ${FilesHashFileNamePath}

  #S3への同期を開始 
  echo "path is " ${S3_PATH}
  flock -n /tmp/s3sync.lock /usr/local/bin/aws s3 sync $SAVEPATH_BASE ${S3_PATH} --delete
  echo "sync end!"

}

# 同期ログにデータを追加する
do_add_synclog(){

  readonly local CompressedFile=${SAVEPATH_BASE}/S3SyncLog.txt.7z

   #対象ファイルが無かったら作る
  if [ -e $CompressedFile ]; then

    touch ${S3SyncLogFileName}

  else
 
    7z e -o ${S3SyncLogFileName} ${CompressedFile}
    mv ${S3SyncLogFileName}.7z ${S3SyncLogFileName}.7z_backup

  fi

  #ログを追加
  echo "add log : " $1
  echo $1 >> ${S3SyncLogFileName}

  #ログを圧縮
  time nice -n 19 7z a -mx=9 ${CompressedFile} ${S3SyncLogFileName} 
  rm -f ${S3SyncLogFileName}.7z_backup
  rm -f ${S3SyncLogFileName}
}

# --- 主関数

if [ -e $AWS_CONFIG ]; then

  echo "start new S3 backup!"

  # 設定ファイルを読み込み
  source /root/.aws/S3Config.sh

  S3Files=`/usr/local/bin/aws s3 ls s3://${S3_TARGET_BUCKET_NAME}/${S3_TARGET_DIRECTORY_NAME}/ --human | wc -l`

  # 処理対象の情報を記録
  echo "S3Files : " ${S3Files}
    
  # 該当のS3フォルダが無かったら新規追加扱いとする。
  # 初期状態扱いとする
  if [ "${S3Files}" == "0" ]; then
    # S3への初期同期状態

    echo "On initial"
    do_s3_sync "false"

  else
    # S3への追加同期状態
  
    # S3パスからダウンロードログを取得する
    /usr/local/bin/aws s3 cp s3://${S3_TARGET_BUCKET_NAME}/${S3_TARGET_DIRECTORY_NAME}/${FilesHashFileName}.7z ${TempDir}/

    # 比較対象を解凍する
    7z e -o${TempDir} ${TempDir}/${FilesHashFileName}.7z
    mv ${TempDir}/${FilesHashFileName} ${TempDir}/${FilesHashFileName}.s3
    7z e -o${TempDir} ${FilesHashFileNamePath}.7z
    mv ${TempDir}/${FilesHashFileName} ${TempDir}/${FilesHashFileName}.org

    #ファイルが一致するか比較する
    diff ${TempDir}/${FilesHashFileName}.s3 ${TempDir}/${FilesHashFileName}.org

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


