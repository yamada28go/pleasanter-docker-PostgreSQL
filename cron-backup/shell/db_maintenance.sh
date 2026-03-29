#!/bin/bash

SCRIPT_DIR=$(cd $(dirname $0); pwd)
source ${SCRIPT_DIR}/pg_rman_env.sh

# DBをメンテナンスする
vacuumdb -v -z -a -U "$DB_USER" -h "$DB_HOST" -p "$DB_PORT"
reindexdb --concurrently -v -d "$DB_NAME" -U "$DB_USER" -h "$DB_HOST" -p "$DB_PORT"
