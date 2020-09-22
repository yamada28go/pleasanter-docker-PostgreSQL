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

do_s3_sync () {

  is_safe=$1

  #S3の設定が確認できた場合
  echo "start S3Sync default path"
  echo ${is_safe}

  if "${is_safe}" ; then
    echo "safe mode"
    echo `date +%Y%m%d_%H-%M-%S` >> ${SAVEPATH_BASE}/S3SyncLog.txt
    echo 'safe-mode' >> ${SAVEPATH_BASE}/S3SyncLog.txt
    readonly local S3_PATH=s3://${S3_TARGET_BUCKET_NAME}/${S3_TARGET_DIRECTORY_NAME}-safe
  else
    echo "not safe mode"
    echo `date +%Y%m%d_%H-%M-%S` >> ${SAVEPATH_BASE}/S3SyncLog.txt
    readonly local S3_PATH=s3://${S3_TARGET_BUCKET_NAME}/${S3_TARGET_DIRECTORY_NAME}
  fi
  echo "path is " ${S3_PATH}
  flock -n /tmp/s3sync.lock /usr/local/bin/aws s3 sync $SAVEPATH_BASE ${S3_PATH} --delete
  echo "sync end!"

}

# --- 主関数

if [ -e $AWS_CONFIG ]; then

  echo "start new S3 backup!"

  source /root/.aws/S3Config.sh

  # 対象となるフォルダのファイル数を比較。
  # 5%以上違っていたら、エラーなので指定されたディレクトリへのバックアップは実行しない。
  # 新しく作った予備のs3ディレクトリにバックアップを行う。
  #
  # 新規にインスタンスを立ち上げて、既存のバックアップはフォルダに対して、
  # 間違って上書きをしないように対応する。

  S3Files=`/usr/local/bin/aws s3 ls s3://${S3_TARGET_BUCKET_NAME}/${S3_TARGET_DIRECTORY_NAME} --recursive --human | wc -l`
  LocalFiles=`find $SAVEPATH_BASE -type f | wc -l`

  echo "S3Files : " ${S3Files}
  echo "LocalFiles : " ${LocalFiles}
  
  
  # S3のデータ件数が1件 or 0件だったら
  # 初期状態扱いとする
  if [ "${S3Files}" == "0" -o  "${S3Files}" == "1" ]; then

    echo "On initial"

    do_s3_sync "false"

  else
  
    # S3パスからダウンロードログを取得する
    /usr/local/bin/aws s3 cp s3://${S3_TARGET_BUCKET_NAME}/${S3_TARGET_DIRECTORY_NAME}/S3SyncLog.txt ${TempDir}/

    #ファイルが一致するか比較する
    diff ${TempDir}/S3SyncLog.txt ${SAVEPATH_BASE}/S3SyncLog.txt

    ret=$?

    if [ $ret -eq 0 ] ;then

      echo "log dir has no problem start additional sync mode"
      do_s3_sync "false"

    else

      echo "log dir has problem start safe sync mode"
      do_s3_sync "true"

    fi
  
  fi

  exit
  
#   # データ件数が有る場合、
#   # S3から実行ログを取得して
#   # 現在の実行ログと同一化比較する
  
#   # 同一な場合
  
#   # 異なる場合

#   TCAL=(`echo "scale=5; (${S3Files} / ${LocalFiles}) * 100" | bc`)
#   TCAL_R=(`printf '%.f \n' ${TCAL}`)
#   echo "diff ${TCAL_R}"

#   # ファイル数の差が5%以内なら指定ディレクトリにコピーする
#   if [ ${TCAL_R} -lt 5 ]; then

#     #S3の設定が確認できた場合
#     echo "start S3Sync default path"
#     echo `date +%Y%m%d_%H-%M-%S` >> ${SAVEPATH_BASE}/S3SyncLog.txt
#     flock -n /tmp/s3sync.lock /usr/local/bin/aws s3 sync $SAVEPATH_BASE s3://${S3_TARGET_BUCKET_NAME}/${S3_TARGET_DIRECTORY_NAME} --delete

#   else

#     # 5%以上ずれている場合、新たに作った安全領域にコピーする
#     echo "start S3Sync safe path"
#     echo `date +%Y%m%d_%H-%M-%S` >> ${SAVEPATH_BASE}/S3SyncLog.txt
#     flock -n /tmp/s3sync.lock /usr/local/bin/aws s3 sync $SAVEPATH_BASE s3://${S3_TARGET_BUCKET_NAME}/${S3_TARGET_DIRECTORY_NAME}-safe --delete

#   fi

#   echo "end new S3 backup!"

# else

#   echo "S3 config not found!"

 fi


