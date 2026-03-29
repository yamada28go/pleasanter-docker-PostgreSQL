#!/bin/bash

# 設定値を読み込む
SCRIPT_DIR=$(cd $(dirname $0); pwd)
source ${SCRIPT_DIR}/pg_rman_env.sh

# ARCLOGのパスを両コンテナが見えるようにしておく
chmod 777 $ARCLOG_PATH

# バックアップの実施種別
BACKUP_TYPE=$1

if [ ! -e $SAVEPATH_BASE ]; then

  echo "Start new backup!"

  # 存在しない場合
  # 作業ディレクトリを作成
  mkdir -p $SAVEPATH_BASE

  # DBバックアップ処理を初期化する
  pg_rman init -B $SAVEPATH_BASE $HOST_CONFIG

  # 初回はFullバックアップとする
  BACKUP_TYPE="FULL"

fi

# 指定内容に応じてバックアップを実行
case ${BACKUP_TYPE} in
  "INCREMENTAL")
    # 差分バックアップ
    echo "INCREMENTAL Backup"
    time nice -n 19 pg_rman backup --backup-mode=incremental --compress-data --progress $HOST_CONFIG --dbname "$DB_NAME";;
  *)
    # 初期バックアップを起動
    echo "FULL Backup"
    time nice -n 19 pg_rman backup --backup-mode=full --compress-data --progress $HOST_CONFIG --dbname "$DB_NAME";;
esac

#バリデーションチェック
time nice -n 19 pg_rman validate

# 古くなったバックアップファイルを削除する
DELETE_DATA=`date -d "${KEEP_DATA_DAYS} days ago" +"%Y-%m-%d"`
echo "Delete old backup. bedore : $DELETE_DATA"
pg_rman delete ${DELETE_DATA} 00:00:00

# S3同期を行う
SCRIPT_DIR=$(cd $(dirname $0); pwd)
source ${SCRIPT_DIR}/syncToS3.sh PITR true
