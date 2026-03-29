#!/bin/bash

PG_MAJOR="${POSTGRES_VERSION:-18}"
export PATH="$PATH:/usr/lib/postgresql/${PG_MAJOR}/bin/"

# アーカイブログの保持日数を指定
export KEEP_ARCLOG_DAYS=1
# バックアップの保持日数を指定
export KEEP_DATA_DAYS=1

# バックアップ先ディレクトリ
export SAVEPATH_BASE='/var/db_backup/PITR'
export BACKUP_PATH=$SAVEPATH_BASE
export PGDATA="${POSTGRES_VOLUMES_TARGET:-/var/lib/postgresql/data}"
export ARCLOG_PATH=/var/lib/postgresql/arclog

# ユーザー設定
export HOST_CONFIG='--host=postgres-db --username postgres'
