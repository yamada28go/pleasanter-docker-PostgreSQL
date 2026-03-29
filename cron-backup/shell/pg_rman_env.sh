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
export ARCLOG_PATH="${POSTGRES_ARCLOG_PATH:-/var/lib/postgresql/arclog}"

# DB接続設定
export DB_HOST="${BACKUP_DB_HOST:-postgres-db}"
export DB_PORT="${BACKUP_DB_PORT:-5432}"
export DB_NAME="${POSTGRES_DB:-postgres}"
export DB_USER="${BACKUP_DB_USER:-postgres}"
export PGPASSWORD="${PGPASSWORD:-${POSTGRES_PASSWORD:-}}"
export HOST_CONFIG="--host=${DB_HOST} --port=${DB_PORT} --username ${DB_USER}"
