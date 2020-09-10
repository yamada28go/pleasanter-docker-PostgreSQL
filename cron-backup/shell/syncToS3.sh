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

  TCAL=(`echo "scale=5; (${S3Files} / ${LocalFiles}) * 100" | bc`)
  TCAL_R=(`printf '%.f \n' ${TCAL}`)
  echo "diff ${TCAL_R}"

  # ファイル数の差が5%以内なら指定ディレクトリにコピーする
  if [ ${TCAL_R} -lt 5 ]; then

    #S3の設定が確認できた場合
    echo "start S3Sync default path"
    echo `date +%Y%m%d_%H-%M-%S` >> ${SAVEPATH_BASE}/S3SyncLog.txt
    flock -n /tmp/s3sync.lock /usr/local/bin/aws s3 sync $SAVEPATH_BASE s3://${S3_TARGET_BUCKET_NAME}/${S3_TARGET_DIRECTORY_NAME} --delete

  else

    # 5%以上ずれている場合、新たに作った安全領域にコピーする
    echo "start S3Sync safe path"
    echo `date +%Y%m%d_%H-%M-%S` >> ${SAVEPATH_BASE}/S3SyncLog.txt
    flock -n /tmp/s3sync.lock /usr/local/bin/aws s3 sync $SAVEPATH_BASE s3://${S3_TARGET_BUCKET_NAME}/${S3_TARGET_DIRECTORY_NAME}-safe --delete

  fi

  echo "end new S3 backup!"

else

  echo "S3 config not found!"

fi


