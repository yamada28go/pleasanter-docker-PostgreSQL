## 設定ファイル

設定は 2 ファイルに分けています。

- `.env`
  - Git 管理してよい非秘匿設定
- `.env.secrets`
  - パスワードや接続文字列などの秘匿情報

## `.env`

```env
# PostgreSQL のメジャーバージョン
POSTGRES_VERSION=18

# pg_rman の取得バージョン
PG_RMAN_VERSION=V1.3.19

# コンテナと PostgreSQL で共通利用するタイムゾーン
APP_TIMEZONE=UTC

# PostgreSQL データディレクトリのマウント先
POSTGRES_VOLUMES_TARGET=/var/lib/postgresql/data

# WAL アーカイブログの配置先
POSTGRES_ARCLOG_PATH=/var/lib/postgresql/arclog

# PostgreSQL 管理者ユーザー名
POSTGRES_USER=postgres

# 初期化時に作成するデータベース名
POSTGRES_DB=postgres

# ホスト認証方式
POSTGRES_HOST_AUTH_METHOD=scram-sha-256

# initdb に渡す追加引数
POSTGRES_INITDB_ARGS="--auth-host=scram-sha-256"

# バックアップ系スクリプトが接続する PostgreSQL ホスト名
BACKUP_DB_HOST=postgres-db

# バックアップ系スクリプトが接続する PostgreSQL ポート番号
BACKUP_DB_PORT=5432

# バックアップ系スクリプトが接続する PostgreSQL ユーザー名
BACKUP_DB_USER=postgres

# Pleasanter コンテナのバージョン
PLEASANTER_VERSION=latest
```

`APP_TIMEZONE` は `postgres-db` と `cron-backup` の両方に渡されます。安全優先の構成では `UTC` を推奨し、Pleasanter の表示タイムゾーンだけを CodeDefiner の `/z "Asia/Tokyo"` で JST に寄せます。

必要に応じて、以下の PostgreSQL 起動オプションも `.env` に追加して上書きできます。

```env
# PostgreSQL の待受アドレス
POSTGRES_LISTEN_ADDRESSES=*

# WAL アーカイブを有効化するか
POSTGRES_ARCHIVE_MODE=on

# WAL レベル
POSTGRES_WAL_LEVEL=replica

# WAL アーカイブ時のコピーコマンド
POSTGRES_ARCHIVE_COMMAND=cp %p /var/lib/postgresql/arclog/%f
```

## `.env.secrets`

`.env.secrets.example` をコピーして作成します。

```bash
cp .env.secrets.example .env.secrets
```

例:

```env
# PostgreSQL の管理者ユーザー postgres のパスワード
POSTGRES_PASSWORD=change_me

# pg_dumpall の 7z 暗号化に使うパスワード
ZIP_PASSWORD=change_me

# S3 同期を有効にする場合は 1 を設定
ENABLE_S3_BACKUP=

# S3 同期に使う AWS アクセスキー
AWS_ACCESS_KEY_ID=

# S3 同期に使う AWS シークレットキー
AWS_SECRET_ACCESS_KEY=

# S3 同期に使う AWS リージョン
AWS_DEFAULT_REGION=ap-northeast-1

# S3 同期先バケット名
S3_TARGET_BUCKET_NAME=

# S3 同期先ディレクトリ名
S3_TARGET_DIRECTORY_NAME=DB_Backup

# CodeDefiner / Pleasanter が PostgreSQL 管理者で接続するための接続文字列
Implem.Pleasanter_Rds_PostgreSQL_SaConnectionString=Server=postgres-db;Database=postgres;UID=postgres;PWD=change_me

# CodeDefiner / Pleasanter が Owner ユーザーで接続するための接続文字列
Implem.Pleasanter_Rds_PostgreSQL_OwnerConnectionString=Server=postgres-db;Database=#ServiceName#;UID=#ServiceName#_Owner;PWD=change_me

# CodeDefiner / Pleasanter が User ユーザーで接続するための接続文字列
Implem.Pleasanter_Rds_PostgreSQL_UserConnectionString=Server=postgres-db;Database=#ServiceName#;UID=#ServiceName#_User;PWD=change_me
```
