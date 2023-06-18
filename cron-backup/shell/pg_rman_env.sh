#!/bin/bash


export PATH=$PATH:/usr/lib/postgresql/15/bin/

# アーカイブログの保持日数を指定
export KEEP_ARCLOG_DAYS=1
# バックアップの保持日数を指定
export KEEP_DATA_DAYS=1

# バックアップ先ディレクトリ
export SAVEPATH_BASE='/var/db_backup/PITR'
export BACKUP_PATH=$SAVEPATH_BASE
export PGDATA=/var/lib/postgresql/data
export ARCLOG_PATH=/var/lib/postgresql/arclog

# ユーザー設定
export HOST_CONFIG='--host=postgres-db --username postgres'

# # ARCLOGのパスを両コンテナが見えるようにしておく
# chmod 777 $ARCLOG_PATH

# # バックアップの実施種別
# BACKUP_TYPE=$1

