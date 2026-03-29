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
docker compose exec postgres-db psql -U postgres -d postgres -c "select pg_terminate_backend(pid) from pg_stat_activity where pid <> pg_backend_pid() and datname = 'Implem.Pleasanter';"
docker compose exec postgres-db psql -U postgres -d postgres -c 'drop database if exists "Implem.Pleasanter";'
```

補足:

- この手順は `Implem.Pleasanter` DB だけを削除します
- ロールや他の DB は削除しません
- `pg_dumpall` の内容に `CREATE DATABASE "Implem.Pleasanter"` が含まれている前提です

### 4. バックアップ対象ファイルの一覧を確認

まず、`dumpall` 配下にあるバックアップファイルを確認します。
(更新日時順に確認)

```bash
docker compose exec cron-backup bash -lc 'find /var/db_backup/dumpall -type f -exec ls -lht {} +'
```

### 5. 対象の `.7z` を展開

```bash
docker compose exec cron-backup bash -lc '7z x /var/db_backup/dumpall/backup.7z -p"$ZIP_PASSWORD" -o/var/db_backup/restore'
```

ホスト上の外部ファイルを使う場合は、一時的にマウントして展開できます。

サンプル:

```bash
docker compose run --rm --no-deps \
  -v /path/to/backup:/mnt/backup \
  cron-backup \
  bash -lc '7z x /mnt/backup/backup.7z -p"$ZIP_PASSWORD" -o/var/db_backup/restore'
```

この例では、ホスト側の `/path/to/backup/backup.7z` をコンテナ内の `/mnt/backup/backup.7z` として参照しています。

### 6. PostgreSQL への接続を止める

最低限、`pleasanter-web` を止めた状態で復元します。
さらに厳密に行うなら、`postgres-db` に直接入ってセッションを確認し、不要な接続が残っていないことを確認します。

接続確認例:

```bash
docker compose exec postgres-db psql -U postgres -d postgres -c "select pid, usename, datname, state, query from pg_stat_activity order by pid;"
```

クライアント接続だけを観察する例:

```bash
docker compose exec postgres-db psql -U postgres -d postgres -c "select pid, usename, datname, client_addr, application_name, state, query from pg_stat_activity where backend_type = 'client backend' order by pid;"
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
docker compose exec postgres-db psql -U postgres -d postgres -c "select pg_terminate_backend(pid) from pg_stat_activity where pid <> pg_backend_pid() and datname = 'postgres';"
```

### 7. SQL を流し込む

展開した SQL を `cron-backup` コンテナから PostgreSQL に流し込みます。

```bash
docker compose exec cron-backup bash -lc 'psql -h postgres-db -p 5432 -U postgres -d postgres -f /path/to/backup.sql'
```

`cron-backup` コンテナ内で参照できる SQL を流す例です。`/path/to/backup.sql` は実際のファイルに置き換えてください。

ホスト上の SQL を一時マウントして流し込むサンプル:

```bash
docker compose run --rm --no-deps \
  -v /path/to/restore:/mnt/restore \
  cron-backup \
  bash -lc 'psql -h postgres-db -p 5432 -U postgres -d postgres -f /mnt/restore/backup.sql'
```

この例では、ホスト側の `/path/to/restore/backup.sql` を `cron-backup` コンテナ内の `/mnt/restore/backup.sql` として読み込み、そこから `postgres-db` へ接続しています。

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

```bash
docker compose stop pleasanter-web
docker compose exec cron-backup flock --timeout=600 /tmp/db_backup.lock /var/backup_sh/pg_dumpall.sh
docker compose exec postgres-db psql -U postgres -d postgres -c "select pg_terminate_backend(pid) from pg_stat_activity where pid <> pg_backend_pid() and datname = 'Implem.Pleasanter';"
docker compose exec postgres-db psql -U postgres -d postgres -c 'drop database if exists "Implem.Pleasanter";'
docker compose exec cron-backup bash -lc 'find /var/db_backup/dumpall -type f -exec ls -lht {} +'
docker compose exec cron-backup bash -lc '7z x /var/db_backup/dumpall/backup.7z -p"$ZIP_PASSWORD" -o/var/db_backup/restore'
docker compose exec postgres-db psql -U postgres -d postgres -c "select pid, usename, datname, state, query from pg_stat_activity order by pid;"
docker compose exec postgres-db psql -U postgres -d postgres -c "select pg_terminate_backend(pid) from pg_stat_activity where pid <> pg_backend_pid() and datname = 'postgres';"
docker compose exec cron-backup bash -lc 'psql -h postgres-db -p 5432 -U postgres -d postgres -f /path/to/backup.sql'
docker compose up -d pleasanter-web
```

## 注意点

- `pg_dumpall` 復元は SQL の再実行なので、既存状態と競合することがあります
- 本番 DB に直接流し込む前に、可能なら別環境で一度検証してください
- 途中で戻したくなる可能性があるため、復元直前バックアップの取得を推奨します
