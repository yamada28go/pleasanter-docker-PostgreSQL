#!/bin/bash


export PATH=$PATH:/usr/lib/postgresql/12/bin/

# バックアップファイルを残しておく日数
PERIOD='+90'

# バックアップ先ディレクトリ
SAVEPATH_BASE='/var/db_backup/PITR'
export BACKUP_PATH=$SAVEPATH_BASE
export PGDATA=/var/lib/postgresql/data
export ARCLOG_PATH=/var/lib/postgresql/arclog

# ユーザー設定
HOST_CONFIG='--host=postgres-db --username postgres'

# ARCLOGのパスを両コンテナが見えるようにしておく
chmod 777 $ARCLOG_PATH

if [ ! -e $SAVEPATH_BASE ]; then

  echo "start new backup!"

  # 存在しない場合
  # 作業ディレクトリを作成
  mkdir -p $SAVEPATH_BASE

  # DBバックアップ処理を初期化する
  pg_rman init -B $SAVEPATH_BASE $HOST_CONFIG

  # 初期バックアップを起動
  time nice -n 19 pg_rman backup --backup-mode=full --compress-data --progress $HOST_CONFIG --dbname Implem.Pleasanter

else

  echo "start incremental backup!"

  # 差分バックアップ
  time nice -n 19 pg_rman backup --backup-mode=incremental --compress-data --progress $HOST_CONFIG --dbname Implem.Pleasanter


fi

#バリデーションチェック
time nice -n 19 pg_rman validate

# S3同期を行う
SCRIPT_DIR=$(cd $(dirname $0); pwd)
source ${SCRIPT_DIR}/syncToS3.sh

