## PITR 復元

PITR 復元は、`pg_rman` バックアップと WAL を使って共有データ領域を復旧する手順です。
復元時は PostgreSQL への書き込みを止める必要があるため、先にアプリ停止を行います。

### 事前準備と注意

PITR を始めると、`db-data` volume 上の PostgreSQL データは復元対象時点の内容で上書きされます。
そのため、途中で「やはり PITR 実施前の状態に戻したい」となっても、自動では戻せません。

考え方:

- PITR は「過去の時点に戻す」操作であり、実行時点の DB 状態を保持する操作ではありません
- `pg_wal_replay_resume()` を実行する前でも、`PGDATA` 自体はすでに復元内容へ置き換わっています
- 途中で中止しても、PITR 前の状態へ自動復帰はできません

推奨:

- PITR 実行前に、少なくとも `pg_dumpall` をもう一度取得する
- より厳密に戻せるようにしたい場合は、`db-data` volume 自体の退避方法も事前に決めておく

最低限の実施例:

```bash
docker compose exec cron-backup flock --timeout=600 /tmp/db_backup.lock /var/backup_sh/pg_dumpall.sh
```

このバックアップは、「PITR 実施直前の最新状態を退避しておく」ための保険として扱います。

### 1. 復元対象時刻とバックアップ一覧を確認

まず、どの時刻まで戻すかを決めて、`pg_rman` の取得済みバックアップを確認します。

```bash
docker compose exec cron-backup bash -lc 'source /var/backup_sh/pg_rman_env.sh && pg_rman show'
```

### 2. Pleasanter と PostgreSQL を停止

復元中に更新が入らないように、Pleasanter と PostgreSQL を停止します。

```bash
docker compose stop pleasanter-web postgres-db
```

### 3. `pg_rman restore` を実行

`cron-backup` と `postgres-db` は同じ DB データ volume を見ているため、`cron-backup` 側から復元できます。
PostgreSQL は停止済みなので、`--no-deps` を付けた一時コンテナで実行します。

指定時刻へ復元する例:

```bash
docker compose run --rm --no-deps cron-backup bash -lc "source /var/backup_sh/pg_rman_env.sh && pg_rman restore --recovery-target-time '2026-03-29 19:00:00'"
```

必要に応じて、`pg_rman show` で確認した整合の取れた時刻を指定してください。

### 4. PostgreSQL を起動

復元後、PostgreSQL を起動します。

```bash
docker compose up -d postgres-db
```

ログ確認:

```bash
docker compose logs -f postgres-db
```

PITR では、目標時刻に達すると PostgreSQL が read-only のまま一時停止することがあります。
ログに以下のような内容が出たら、復元自体は成功しており、次に昇格操作が必要です。

- `pausing at the end of recovery`
- `Execute pg_wal_replay_resume() to promote.`

### 5. PostgreSQL を primary として昇格

復元後に read-only で停止している場合は、`pg_wal_replay_resume()` を実行して復旧を完了させます。

```bash
docker compose exec postgres-db psql -U postgres -d postgres -c "select pg_wal_replay_resume();"
```

昇格後も、引き続き PostgreSQL ログを確認します。

```bash
docker compose logs -f postgres-db
```

`pleasanter-web` を先に起動すると、read-only 状態の DB に書き込みに行って `cannot execute DELETE in a read-only transaction` になるため、必ず昇格完了を先に確認してください。

### 6. Pleasanter を再起動

PostgreSQL の復旧が完了したら、Pleasanter を再起動します。

```bash
docker compose up -d pleasanter-web
```

### 7. 動作確認

復元後は、以下を確認します。

- 復元対象時刻
- PostgreSQL が正常起動していること
- Pleasanter にログインできること
- 期待した時点のデータに戻っていること
- 復元確認方法

### コマンド例まとめ

以下は、`2026-03-29 19:01:00` 時点へ PITR 復元する場合の一連の例です。

```bash
docker compose exec cron-backup bash -lc 'source /var/backup_sh/pg_rman_env.sh && pg_rman show'
docker compose stop pleasanter-web postgres-db
docker compose run --rm --no-deps cron-backup bash -lc "source /var/backup_sh/pg_rman_env.sh && pg_rman restore --recovery-target-time '2026-03-29 19:01:00'"
docker compose up -d postgres-db
docker compose logs -f postgres-db
docker compose exec postgres-db psql -U postgres -d postgres -c "select pg_wal_replay_resume();"
docker compose logs -f postgres-db
docker compose up -d pleasanter-web
```

### ログの見方

PITR 復元後の `postgres-db` ログでは、以下の流れで確認します。

1. 復元対象時刻で recovery が開始されていること
2. `pausing at the end of recovery` が出て、目標時刻で停止していること
3. `pg_wal_replay_resume()` 実行後に timeline が進み、`archive recovery complete` が出ること
4. 最後に `database system is ready to accept connections` が出ること

成功時の例:

```text
2026-03-29 19:06:15.600 JST [33] LOG:  starting point-in-time recovery to 2026-03-29 19:00:04+09
2026-03-29 19:06:15.981 JST [33] LOG:  recovery stopping before commit of transaction 902, time 2026-03-29 19:00:04.056087+09
2026-03-29 19:06:15.981 JST [33] LOG:  pausing at the end of recovery
2026-03-29 19:06:15.981 JST [33] HINT:  Execute pg_wal_replay_resume() to promote.
2026-03-29 19:06:15.981 JST [1] LOG:  database system is ready to accept read-only connections
2026-03-29 19:06:28.151 JST [33] LOG:  selected new timeline ID: 3
2026-03-29 19:06:28.281 JST [33] LOG:  archive recovery complete
2026-03-29 19:06:28.454 JST [1] LOG:  database system is ready to accept connections
```

読み方:

- `starting point-in-time recovery to ...`
  - 指定した時刻へ向けて PITR を開始しています
- `recovery stopping before commit of transaction ...`
  - 指定時刻をまたぐトランザクションの直前で停止しています
- `pausing at the end of recovery`
  - 目標時刻で止まり、まだ read-only 状態です
- `ready to accept read-only connections`
  - まだ昇格前です。`pleasanter-web` を起動してはいけません
- `selected new timeline ID: 3`
  - `pg_wal_replay_resume()` 後に新しい timeline へ昇格しています
- `archive recovery complete`
  - PITR が完了しています
- `ready to accept connections`
  - 通常の primary として起動完了です。このあと `pleasanter-web` を起動します

注意が必要なログ:

- `cannot execute DELETE in a read-only transaction`
  - `pleasanter-web` を昇格前に起動しています。先に `docker compose stop pleasanter-web` してから `pg_wal_replay_resume()` を実行してください
- `recovery ended before configured recovery target was reached`
  - 指定時刻まで到達する WAL が不足しています
- `configuration file ... contains errors`
  - `pg_rman_recovery.conf` と `postgresql.conf` の include 状態が壊れている可能性があります
