## バックアップ / 復元

`cron-backup` コンテナでバックアップと DB メンテナンスを行います。

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
| `pg_rman` FULL | PITR の起点となる日次フルバックアップ | ローカル volume | その日の差分バックアップと WAL の基準になります |
| `pg_rman` INCREMENTAL | 日中の差分バックアップ | ローカル volume | 同日内の細かい時点復旧に使います |
| WAL アーカイブ | PITR の時点復旧 | ローカル volume | `pg_rman` の FULL / INCREMENTAL と組み合わせて使います |
| `pg_dumpall` | DB 全体の退避、別環境への移行、最終退避 | ローカル volume と必要に応じた外部保管 | PITR とは別系統の保険です |

S3 への保管方針としては、日次のフルバックアップを長めに保持するバックアップとして扱う想定です。
一方で、短期保持用のバックアップ領域へは同じ内容を二重に同期しない前提としています。

つまり運用イメージは次のとおりです。

- ローカル:
  - 直近の FULL / INCREMENTAL / WAL を保持して、素早く PITR できるようにする
- S3:
  - 日次フルバックアップを退避して、中長期の保管先とする
- 短期バックアップ領域:
  - ローカルの即時復旧用途を優先し、S3 上のフルバックアップと重複運用しない

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

PITR 復元の詳細手順、ログの見方、`pg_wal_replay_resume()` による昇格手順は別ファイルに分離しています。

- [PITR 復元手順](./pitr-restore.md)

概要:

- `pg_rman show` で復元候補時刻を確認する
- `pleasanter-web` と `postgres-db` を停止する
- `pg_rman restore --recovery-target-time ...` を実行する
- `postgres-db` を起動して recovery ログを確認する
- 必要に応じて `pg_wal_replay_resume()` で primary へ昇格する
- 最後に `pleasanter-web` を起動する

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
