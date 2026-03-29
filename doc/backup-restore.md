## バックアップ / 復元

このリポジトリでは `cron-backup` コンテナでバックアップとdbのメンテナンス動作を行います。

- `pg_dumpall` による全体ダンプ
- `pg_rman` による PITR 用バックアップ

バックアップ結果は主に以下へ保存されます。

- `/var/db_backup/dumpall`
- `/var/db_backup/PITR`

## バックアップ方針

この構成では、バックアップを大きく 2 系統で考えます。

- `pg_dumpall`
  - DB 全体をまとめて取得する論理バックアップです
- `pg_rman`
  - WAL を使って任意時点へ戻すための PITR 用バックアップです

PITR は、日次のフルバックアップを起点に、その後の差分バックアップと WAL を積み上げて同日内の復旧を行う想定です。
そのため、少なくとも 1 日に 1 回のフルバックアップが成立していることを前提にしています。

整理すると以下の考え方です。

| 種別 | 主な用途 | 想定保持場所 | 補足 |
| --- | --- | --- | --- |
| `pg_rman` FULL | PITR の起点となる日次フルバックアップ | ローカル volume と S3 | その日の差分バックアップと WAL の基準になります |
| `pg_rman` INCREMENTAL | 日中の差分バックアップ | ローカル volume | 同日内の細かい時点復旧に使います |
| WAL アーカイブ | PITR の時点復旧 | ローカル volume | `pg_rman` の FULL / INCREMENTAL と組み合わせて使います |
| `pg_dumpall` | DB 全体の退避、別環境への移行、最終退避 | ローカル volume と必要に応じて外部保管 | PITR とは別系統の保険です |

S3 への保管方針としては、日次のフルバックアップを長めに保持するバックアップとして扱う想定です。
一方で、短期保持用のバックアップ領域へは同じ内容を二重に同期しない前提としています。

つまり運用イメージは次のとおりです。

- ローカル:
  - 直近の FULL / INCREMENTAL / WAL を保持して、素早く PITR できるようにする
- S3:
  - 日次フルバックアップを退避して、中長期の保管先とする
- 短期バックアップ領域:
  - ローカルの即時復旧用途を優先し、S3 上のフルバックアップと重複運用しない

## PITR 実施前の注意

PITR を始めると、`db-data` volume 上の PostgreSQL データは復元対象時点の内容で上書きされます。
そのため、途中で「やはり PITR 実施前の状態に戻したい」となっても、自動では戻せません。

このため、重要な環境では PITR 実行直前にもう一度バックアップまたは退避を取る運用を推奨します。

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

## cron-backup で定期実行している処理

`cron-backup` コンテナでは、以下の cron ジョブが動作しています。

| No | 実行タイミング | コマンド | 用途 |
| --- | --- | --- | --- |
| 1 | 毎日 00:15 | `flock --timeout=600 /tmp/db_backup.lock /var/backup_sh/pg_dumpall.sh` | `pg_dumpall` による全体ダンプを取得します |
| 2 | 30 分ごと | `flock --timeout=300 /tmp/db_backup.lock /var/backup_sh/pg_rman.sh INCREMENTAL` | `pg_rman` による差分バックアップを取得します |
| 3 | 毎日 23:15 | `flock --timeout=300 /tmp/db_backup.lock /var/backup_sh/pg_rman.sh FULL` | `pg_rman` によるフルバックアップを取得します |
| 4 | 毎日 22:45 | `flock --timeout=300 /tmp/db_backup.lock /var/backup_sh/db_maintenance.sh` | DB メンテナンス処理を実行します |

補足:

- すべてのジョブは `flock` で排他制御され、同時実行を避けています

## バックアップ

### `pg_dumpall` による全体ダンプ

```bash
docker compose exec cron-backup flock --timeout=600 /tmp/db_backup.lock /var/backup_sh/pg_dumpall.sh
```

補足:

- 出力は `7z` で暗号化されます
- 暗号化パスワードは `.env.secrets` の `ZIP_PASSWORD`
- 接続先は `.env` の `BACKUP_DB_HOST`, `BACKUP_DB_PORT`, `BACKUP_DB_USER`, `POSTGRES_DB`

### `pg_rman` による PITR バックアップ

初回フルバックアップ:

```bash
docker compose exec cron-backup flock --timeout=300 /tmp/db_backup.lock /var/backup_sh/pg_rman.sh FULL
```

差分バックアップ:

```bash
docker compose exec cron-backup flock --timeout=300 /tmp/db_backup.lock /var/backup_sh/pg_rman.sh INCREMENTAL
```

バックアップ一覧確認:

```bash
docker compose exec cron-backup bash -lc 'source /var/backup_sh/pg_rman_env.sh && pg_rman show'
```

## 復元

### `pg_dumpall` バックアップから復元

1. 対象の `.7z` を展開する
2. PostgreSQL が起動している状態で SQL を流し込む

例:

```bash
docker compose exec -T postgres-db psql -U postgres -d postgres < backup.sql
```

実運用では、復元前に対象 DB の停止、退避、接続遮断を先に決めてください。

### PITR 復元

PITR 復元は、`pg_rman` バックアップと WAL を使って共有データ領域を復旧する手順です。
復元時は PostgreSQL への書き込みを止める必要があるため、先にアプリ停止を行います。

#### 1. 復元対象時刻とバックアップ一覧を確認

まず、どの時刻まで戻すかを決めて、`pg_rman` の取得済みバックアップを確認します。

```bash
docker compose exec cron-backup bash -lc 'source /var/backup_sh/pg_rman_env.sh && pg_rman show'
```

#### 2. Pleasanter と PostgreSQL を停止

復元中に更新が入らないように、Pleasanter と PostgreSQL を停止します。

```bash
docker compose stop pleasanter-web postgres-db
```

#### 3. `pg_rman restore` を実行

`cron-backup` と `postgres-db` は同じ DB データ volume を見ているため、`cron-backup` 側から復元できます。
PostgreSQL は停止済みなので、`--no-deps` を付けた一時コンテナで実行します。

指定時刻へ復元する例:

```bash
docker compose run --rm --no-deps cron-backup bash -lc "source /var/backup_sh/pg_rman_env.sh && pg_rman restore --recovery-target-time '2026-03-29 19:00:00'"
```

必要に応じて、`pg_rman show` で確認した整合の取れた時刻を指定してください。

#### 4. PostgreSQL を起動

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

#### 5. PostgreSQL を primary として昇格

復元後に read-only で停止している場合は、`pg_wal_replay_resume()` を実行して復旧を完了させます。

```bash
docker compose exec postgres-db psql -U postgres -d postgres -c "select pg_wal_replay_resume();"
```

昇格後も、引き続き PostgreSQL ログを確認します。

```bash
docker compose logs -f postgres-db
```

`pleasanter-web` を先に起動すると、read-only 状態の DB に書き込みに行って `cannot execute DELETE in a read-only transaction` になるため、必ず昇格完了を先に確認してください。

#### 6. Pleasanter を再起動

PostgreSQL の復旧が完了したら、Pleasanter を再起動します。

```bash
docker compose up -d pleasanter-web
```

#### 7. 動作確認

復元後は、以下を確認します。

- 復元対象時刻
- PostgreSQL が正常起動していること
- Pleasanter にログインできること
- 期待した時点のデータに戻っていること
- 復元確認方法

#### コマンド例まとめ

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

#### ログの見方

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

## 関連設定

主な関連設定:

- `.env`
  - `POSTGRES_VOLUMES_TARGET`
  - `POSTGRES_ARCLOG_PATH`
  - `BACKUP_DB_HOST`
  - `BACKUP_DB_PORT`
  - `BACKUP_DB_USER`
  - `POSTGRES_DB`
- `.env.secrets`
  - `POSTGRES_PASSWORD`
  - `ZIP_PASSWORD`

## 参考

- [Pleasanter 公式: Dockerで起動する](https://pleasanter.org/ja/manual/getting-started-pleasanter-docker)
- [Qiita: Dockerでバックアップを含む Pleasanter + PostgreSQL 環境を組んでみた](https://qiita.com/yamada28go/items/fe8f85305d388ad30a60)
- [Qiita: pleasanter+PostgreSQL+SSL+docker な構成を作ってみた](https://qiita.com/yamada28go/items/b9e6acdb4cca9572c7a6)
