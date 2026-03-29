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

## S3 同期

S3 同期は、ローカル volume 上のバックアップに加えて、外部保管先にも同じバックアップを退避できるようにするための仕組みです。
つまりこの構成では、バックアップを Docker ホスト内だけに閉じず、S3 側にも複製して多重化できるようにしています。

意図:

- ローカル volume 障害時にもバックアップを失いにくくする
- Docker ホスト外にも退避先を持つ
- 日次バックアップを中長期保管しやすくする

この処理は `cron-backup/shell/syncToS3.sh` が担当しており、`/var/db_backup` 配下を AWS S3 へ `aws s3 sync` します。

### 何が S3 に送られるか

同期先は次の形式です。

- `s3://<S3_TARGET_BUCKET_NAME>/<S3_TARGET_DIRECTORY_NAME>/<category>`

この `<category>` には、呼び出し元から `dumpall`, `PITR`, `syslog` などが渡されます。

現状の実装では次のようになっています。

- `pg_dumpall.sh`
  - `syncToS3.sh dumpall false` を呼ぶため、`dumpall` バックアップは S3 同期可能です
- `pg_rman.sh`
  - S3 同期呼び出しの記述はありますが、現状はコメントアウトされているため `PITR` バックアップはデフォルトでは S3 同期されません
- `syslogs_maintenance.sh`
  - `syncToS3.sh syslog false` を呼びますが、cron 自体がコメントアウトされているため現状は自動実行されません

### 有効化条件

- `cron-backup` コンテナに `ENABLE_S3_BACKUP` が環境変数として渡っていること
- `/root/.aws/config` と `/root/.aws/S3Config.sh` が `cron-backup` コンテナ内に存在すること
- `S3Config.sh` で `S3_TARGET_BUCKET_NAME` と `S3_TARGET_DIRECTORY_NAME` が設定されていること

ここで重要なのは、`ENABLE_S3_BACKUP` はホスト側にあるだけではなく、`cron-backup` コンテナ内で見えている必要があることです。
つまり、`.env` や `.env.secrets` に書いた値を Compose 経由でコンテナへ渡す必要があります。

また、AWS 設定ファイルは `cron-backup` コンテナ内の `/root/.aws/` に見えている必要があります。
このリポジトリでは、そのための mount 設定が `docker-compose.yml` にコメントアウトされた状態で入っています。

```yaml
cron-backup:
  env_file:
    - .env
    - .env.secrets
  volumes:
    # aws cliの設定を以下パスに行う。
    # 存在しない場合はバックアップは行われない
    - ./cron-backup/config/aws-cli:/root/.aws/
```

### 設定手順

運用で S3 同期を有効にする場合は、少なくとも次を揃えます。

1. `.env.secrets` などに `ENABLE_S3_BACKUP=1` を設定する
2. `docker-compose.yml` の `cron-backup` で `./cron-backup/config/aws-cli:/root/.aws/` を有効にする
3. `cron-backup/config/aws-cli/config` に AWS CLI の設定を書く
4. `cron-backup/config/aws-cli/S3Config.sh` にバケット名とディレクトリ名を書く

設定例:

`.env.secrets`

```env
ENABLE_S3_BACKUP=1
```

`cron-backup/config/aws-cli/S3Config.sh`

```bash
export S3_TARGET_BUCKET_NAME=my-backup-bucket
export S3_TARGET_DIRECTORY_NAME=DB_Backup
```

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
- `pg_dumpall.sh` は末尾で `syncToS3.sh dumpall false` を呼ぶため、S3 設定が有効なら `dumpall` バックアップを S3 同期します
- `pg_rman.sh` の S3 同期呼び出しは現状コメントアウトされているため、`PITR` バックアップはデフォルトでは S3 同期されません
- `syslogs_maintenance.sh` では `syncToS3.sh syslog false` を呼びますが、cron 自体がコメントアウトされているため現状は自動実行されません

## バックアップ

### `pg_dumpall` による全体ダンプ

```bash
docker compose exec cron-backup flock --timeout=600 /tmp/db_backup.lock /var/backup_sh/pg_dumpall.sh
```

補足:

- 出力は `7z` で暗号化されます
- 暗号化パスワードは `.env.secrets` の `ZIP_PASSWORD`
- 接続先は `.env` の `BACKUP_DB_HOST`, `BACKUP_DB_PORT`, `BACKUP_DB_USER`, `POSTGRES_DB`
- S3 設定が有効な場合は、実行後に `syncToS3.sh dumpall false` により `dumpall` ディレクトリが S3 同期されます

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

補足:

- `pg_rman.sh` には S3 同期呼び出しの記述がありますが、現状はコメントアウトされているため `PITR` バックアップは自動では S3 同期されません

## 復元

### `pg_dumpall` バックアップから復元

停止、退避、接続遮断を含む詳細な復元手順は別ファイルに分離しています。

- [pg_dumpall 復元手順](./pg-dumpall-restore.md)

概要:

- `pleasanter-web` を停止して DB 更新を止める
- 必要なら復元直前の `pg_dumpall` を取得する
- 対象の `.7z` を `ZIP_PASSWORD` で展開する
- 接続状況を確認し、必要なら既存接続を切断する
- 展開した SQL を PostgreSQL に流し込む
- 最後に `pleasanter-web` を再起動する

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
- `cron-backup/config/aws-cli/S3Config.sh`
  - `S3_TARGET_BUCKET_NAME`
  - `S3_TARGET_DIRECTORY_NAME`
- `cron-backup/config/aws-cli/config`
  - AWS CLI の接続設定

## 参考

- [Pleasanter 公式: Dockerで起動する](https://pleasanter.org/ja/manual/getting-started-pleasanter-docker)
- [Qiita: Dockerでバックアップを含む Pleasanter + PostgreSQL 環境を組んでみた](https://qiita.com/yamada28go/items/fe8f85305d388ad30a60)
- [Qiita: pleasanter+PostgreSQL+SSL+docker な構成を作ってみた](https://qiita.com/yamada28go/items/b9e6acdb4cca9572c7a6)
