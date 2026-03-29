#!/bin/bash

SCRIPT_DIR=$(cd $(dirname $0); pwd)
source ${SCRIPT_DIR}/../pg_rman_env.sh

# ローカルにバックアップファイルを残しておく日数
PERIOD='+2'

# バックアップ先ディレクトリ
SAVEPATH_BASE='/var/db_backup/syslog'
# 日付
TODAY_DATE=`date '+%Y-%m-%d-%H%M%S'`
# 先頭文字
PREFIX='syslog-'
# 拡張子
EXT='.7z'

#バックアップの開始時刻
TWO_DAYS_AGO=$(date -d "2 days ago" +"%Y-%m-%d")
echo $TWO_DAYS_AGO

#バックアップディレクトリ作成
SAVEPATH=$SAVEPATH_BASE/`date '+%Y%m'`/
mkdir -p $SAVEPATH

# バックアップ実行
BACKUP_FILE=$SAVEPATH$PREFIX$TODAY_DATE$EXT

# ダンプを実行する
# [memo]
# 圧縮パラメータを外部から指定する事はむずかしそうなので、
# 固定パスに出力するものとする。
#
# 出力先パス
# /tmp/__old_syslog_records.7z
psql -h "$DB_HOST" -p "$DB_PORT" -d "$DB_NAME" -U "$DB_USER" -f ${SCRIPT_DIR}/syslogs_maintenance.sql -v target_datetime=$TWO_DAYS_AGO" 00:00:00" 

# 作成されたファイルを所定の場所に移動する
mv /tmp/__old_syslog_records.7z $BACKUP_FILE

# 保存期間が過ぎたファイルの削除
find $SAVEPATH_BASE -type f -daystart -mtime $PERIOD -exec rm {} \;

# 空になったディレクトリを消去
find $SAVEPATH_BASE -type d -empty -delete

# S3同期を行う
source ${SCRIPT_DIR}/../syncToS3.sh syslog false
