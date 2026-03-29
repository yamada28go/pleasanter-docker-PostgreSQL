#!/bin/bash

# 設定値を読み込む
SCRIPT_DIR=$(cd $(dirname $0); pwd)
source ${SCRIPT_DIR}/common.sh
source ${SCRIPT_DIR}/pg_rman_env.sh

# ARCLOGのパスを両コンテナが見えるようにしておく
log_info "pg_rman backup started. host=${DB_HOST} port=${DB_PORT} db=${DB_NAME} pgdata=${PGDATA} arclog=${ARCLOG_PATH}"
chmod 777 $ARCLOG_PATH

# バックアップの実施種別
BACKUP_TYPE=$1

if [ ! -e $SAVEPATH_BASE ]; then

  log_info "Initializing new pg_rman repository: ${SAVEPATH_BASE}"

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
    log_info "Running incremental backup"
    time nice -n 19 pg_rman backup --backup-mode=incremental --compress-data --progress $HOST_CONFIG --dbname "$DB_NAME";;
  *)
    # 初期バックアップを起動
    log_info "Running full backup"
    time nice -n 19 pg_rman backup --backup-mode=full --compress-data --progress $HOST_CONFIG --dbname "$DB_NAME";;
esac

#バリデーションチェック
log_info "Validating latest backup"
time nice -n 19 pg_rman validate

# 古くなったバックアップファイルを削除する
DELETE_DATA=`date -d "${KEEP_DATA_DAYS} days ago" +"%Y-%m-%d"`
log_info "Deleting old backups before ${DELETE_DATA} 00:00:00"
pg_rman delete ${DELETE_DATA} 00:00:00

# # S3同期を行う
# log_info "Starting optional S3 sync for PITR backups"
# source ${SCRIPT_DIR}/syncToS3.sh PITR true
