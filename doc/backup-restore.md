## バックアップ / 復元

このリポジトリでは `cron-backup` コンテナでバックアップとdbのメンテナンス動作を行います。

- `pg_dumpall` による全体ダンプ
- `pg_rman` による PITR 用バックアップ

バックアップ結果は主に以下へ保存されます。

- `/var/db_backup/dumpall`
- `/var/db_backup/PITR`

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

`pg_rman` の復元先候補は以下で確認します。

```bash
docker compose exec cron-backup bash -lc 'source /var/backup_sh/pg_rman_env.sh && pg_rman show'
```

指定時刻へ復元する例:

```bash
docker compose exec cron-backup bash -lc "source /var/backup_sh/pg_rman_env.sh && pg_rman restore --recovery-target-time '2026-03-29 12:00:00'"
```

PITR は PostgreSQL の停止、復旧設定、再起動を伴います。運用手順としては以下を事前に決めておく必要があります。

- 復元対象時刻
- 停止手順
- 復元後の昇格手順
- 復元確認方法

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
