## pg_dumpall バックアップから復元

`pg_dumpall` の復元は、PITR と違って SQL を流し込んで論理的に戻す手順です。
既存 DB へそのまま流し込むと競合や上書きが起きるため、復元前に停止、退避、接続遮断の順を決めて実施します。

## 復元前に決めること

復元前に、少なくとも以下を決めてください。

- 復元対象のバックアップファイル
- 復元先を既存 DB に上書きするか、新しい DB に流し込むか
- Pleasanter の停止時間帯
- 復元失敗時の切り戻し方法

推奨は次の流れです。

- `pleasanter-web` を停止して DB 更新を止める
- 必要なら復元直前の `pg_dumpall` を再取得して退避する
- 復元対象 DB への接続を止める
- SQL を流し込む
- 動作確認後に `pleasanter-web` を再開する

このドキュメントの接続系コマンド例では、できるだけ `.env` / `.env.secrets` の設定値を参照する形にしています。

- `cron-backup` から接続する例
  - `source /var/backup_sh/pg_rman_env.sh` を読み込み、`DB_HOST`, `DB_PORT`, `DB_USER`, `DB_NAME` を使います
- `postgres-db` 内で実行する例
  - `POSTGRES_USER`, `POSTGRES_DB` を使います

なお、`Implem.Pleasanter` を削除する手順だけは「対象アプリ DB 名」を明示する必要があるため、サンプルでは固定名を使っています。

## 標準手順

### 1. Pleasanter を停止

まず、アプリから DB 更新が入らないようにします。

```bash
docker compose stop pleasanter-web
```

### 2. 復元直前のバックアップを退避

復元前の現時点を戻せるように、必要ならもう一度 `pg_dumpall` を取得します。

```bash
docker compose exec cron-backup flock --timeout=600 /tmp/db_backup.lock /var/backup_sh/pg_dumpall.sh
```

### 3. 必要に応じて `Implem.Pleasanter` を削除

既存の `Implem.Pleasanter` DB に対してそのまま SQL を流すと、`relation ... already exists` のように既存テーブルや index と衝突することがあります。
Pleasanter のアプリ DB だけを戻したい場合は、先に対象 DB を削除して空の状態にしてから復元します。

接続を切断してから削除する例:

```bash
docker compose exec postgres-db bash -lc 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "select pg_terminate_backend(pid) from pg_stat_activity where pid <> pg_backend_pid() and datname = '\''Implem.Pleasanter'\'';"'
docker compose exec postgres-db bash -lc 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "drop database if exists \"Implem.Pleasanter\";"'
```

補足:

- この手順は `Implem.Pleasanter` DB だけを削除します
- ロールや他の DB は削除しません
- `pg_dumpall` の内容に `CREATE DATABASE "Implem.Pleasanter"` が含まれている前提です

### 4. 復元に使うファイル形式を確認

まず、どの形式のバックアップを復元するかを確認します。

- この構成で取得した `.7z`
  - 次の手順で展開してから SQL を流し込みます
- 外部で取得したプレーン SQL ダンプ (`.sql`)
  - `.7z` 展開は不要で、後続手順でそのまま流し込みます

この構成で取得したバックアップを使う場合は、`dumpall` 配下の対象ファイルを確認します。
(更新日時順に確認)

```bash
docker compose exec cron-backup bash -lc 'find /var/db_backup/dumpall -type f -exec ls -lht {} +'
```

### 5. `.7z` バックアップを使う場合は展開

#### 5-1. `dumpall` 配下の `.7z` を展開

```bash
docker compose exec cron-backup bash -lc '7z x /var/db_backup/dumpall/backup.7z -p"$ZIP_PASSWORD" -o/var/db_backup/restore'
```

#### 5-2. ホスト上にある外部の `.7z` を展開

外部から持ち込んだ `.7z` を使う場合は、一時的にマウントして展開できます。

サンプル:

```bash
docker compose run --rm --no-deps \
  -v /path/to/backup:/mnt/backup \
  cron-backup \
  bash -lc '7z x /mnt/backup/backup.7z -p"$ZIP_PASSWORD" -o/var/db_backup/restore'
```

この例では、ホスト側の `/path/to/backup/backup.7z` をコンテナ内の `/mnt/backup/backup.7z` として参照しています。

この手順で展開した後は、後続の「SQL を流し込む」手順を使います。

### 6. PostgreSQL への接続を止める

最低限、`pleasanter-web` を止めた状態で復元します。
さらに厳密に行うなら、`postgres-db` に直接入ってセッションを確認し、不要な接続が残っていないことを確認します。

接続確認例:

```bash
docker compose exec postgres-db bash -lc 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "select pid, usename, datname, state, query from pg_stat_activity order by pid;"'
```

クライアント接続だけを観察する例:

```bash
docker compose exec postgres-db bash -lc 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "select pid, usename, datname, client_addr, application_name, state, query from pg_stat_activity where backend_type = '\''client backend'\'' order by pid;"'
```

見方の目安:

- `usename` と `datname` が空の行
  - PostgreSQL の内部プロセスであることが多く、通常は切断対象ではありません
- `query` が `select ... from pg_stat_activity ...` の行
  - 今その場で実行した確認クエリ自身です
- `client backend` で `pleasanter-web` 由来の接続が見える場合
  - まだアプリや外部クライアントが接続中です
- `client backend` が確認用クエリ自身しか出ていない場合
  - 実質的に外部接続は残っていないと判断できます

必要に応じて、対象 DB への既存接続を切断します。

```bash
docker compose exec postgres-db bash -lc 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "select pg_terminate_backend(pid) from pg_stat_activity where pid <> pg_backend_pid() and datname = '\''$POSTGRES_DB'\'';"'
```

### 7. SQL を流し込む

ここでは、復元元の形式に応じて投入方法を選びます。

#### 7-1. 展開済み SQL を `cron-backup` から流し込む

前段で `.7z` を展開して SQL ファイルを用意した場合は、展開済み SQL を `cron-backup` コンテナから PostgreSQL に流し込みます。

```bash
docker compose exec cron-backup bash -lc 'source /var/backup_sh/pg_rman_env.sh && psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -f /path/to/backup.sql'
```

`cron-backup` コンテナ内で参照できる SQL を流す例です。`/path/to/backup.sql` は実際のファイルに置き換えてください。

ホスト上にある展開済み SQL を一時マウントして流し込むサンプル:

```bash
docker compose run --rm --no-deps \
  -v /path/to/restore:/mnt/restore \
  cron-backup \
  bash -lc 'source /var/backup_sh/pg_rman_env.sh && psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -f /mnt/restore/backup.sql'
```

この例では、ホスト側の `/path/to/restore/backup.sql` を `cron-backup` コンテナ内の `/mnt/restore/backup.sql` として読み込み、そこから `postgres-db` へ接続しています。

#### 7-2. 外部のプレーン SQL ダンプ (`.sql`) をそのまま流し込む

外部で取得したプレーンテキスト形式の `.sql` ダンプが手元にある場合は、`postgres-db` に対して標準入力で直接流し込みます。

```bash
docker compose exec -T postgres-db bash -lc 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"' < /path/to/dump.sql
```

補足:

- `-T` は標準入力を流し込むために付けます
- `< /path/to/dump.sql` はホスト側ファイルを読む指定です
- この方法はプレーンテキスト形式の `.sql` ダンプ向けです
- `pg_restore: input file appears to be a text format dump. Please use psql.` と表示された場合は、`pg_restore` ではなくこの `psql` 形式を使ってください

投入先 DB を明示したい場合の例:

```bash
docker compose exec -T postgres-db bash -lc 'psql -U "$POSTGRES_USER" -d Implem.Pleasanter' < /path/to/dump.sql
```

一方で、`.dump` や `.backup` のようなカスタム形式ダンプは `psql` ではなく `pg_restore` を使います。

### 8. Pleasanter を再起動

```bash
docker compose up -d pleasanter-web
```

### 9. 動作確認

復元後は、以下を確認します。

- Pleasanter にログインできること
- 期待した時点のデータに戻っていること
- エラーが出ていないこと

## コマンド例まとめ

共通手順:

```bash
docker compose stop pleasanter-web
docker compose exec cron-backup flock --timeout=600 /tmp/db_backup.lock /var/backup_sh/pg_dumpall.sh
docker compose exec postgres-db bash -lc 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "select pg_terminate_backend(pid) from pg_stat_activity where pid <> pg_backend_pid() and datname = '\''Implem.Pleasanter'\'';"'
docker compose exec postgres-db bash -lc 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "drop database if exists \"Implem.Pleasanter\";"'
docker compose exec postgres-db bash -lc 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "select pid, usename, datname, state, query from pg_stat_activity order by pid;"'
docker compose exec postgres-db bash -lc 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "select pg_terminate_backend(pid) from pg_stat_activity where pid <> pg_backend_pid() and datname = '\''$POSTGRES_DB'\'';"'
```

この構成で取得した `.7z` バックアップを復元する場合:

```bash
docker compose exec cron-backup bash -lc 'find /var/db_backup/dumpall -type f -exec ls -lht {} +'
docker compose exec cron-backup bash -lc '7z x /var/db_backup/dumpall/backup.7z -p"$ZIP_PASSWORD" -o/var/db_backup/restore'
docker compose exec cron-backup bash -lc 'source /var/backup_sh/pg_rman_env.sh && psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -f /path/to/backup.sql'
docker compose up -d pleasanter-web
```

外部のプレーン SQL ダンプ (`.sql`) を復元する場合:

```bash
docker compose exec -T postgres-db bash -lc 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"' < /path/to/dump.sql
docker compose up -d pleasanter-web
```

## 注意点

- `pg_dumpall` 復元は SQL の再実行なので、既存状態と競合することがあります
- 本番 DB に直接流し込む前に、可能なら別環境で一度検証してください
- 途中で戻したくなる可能性があるため、復元直前バックアップの取得を推奨します

## 補足

作業途中でホストから PostgreSQL コンソールに入りたい場合は、次のように `postgres-db` コンテナ内の `psql` を起動できます。

```bash
docker compose exec postgres-db bash -lc 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"'
```
