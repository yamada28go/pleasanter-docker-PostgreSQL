## これは何

Pleasanter を PostgreSQL と一緒に Docker Compose で動かすための構成です。
このリポジトリでは、Pleasanter 本体に加えて以下をまとめて扱えます。

- PostgreSQL
- `cron-backup` コンテナによるバックアップ
- `https-portal` を使った HTTPS 化

`docker-compose.https-portal.yml` を用意しているため、公開ドメインとポート条件が揃っていれば HTTPS 設定も比較的簡単に追加できます。

セットアップの考え方は [Pleasanter 公式の Docker 手順](https://pleasanter.org/ja/manual/getting-started-pleasanter-docker) を基本として調整しています。

安全優先のタイムゾーン方針として、このリポジトリでは DB とバックアップ系の時刻を `UTC` に寄せ、Pleasanter の表示だけを CodeDefiner の `/z "Asia/Tokyo"` で JST にしています。

## 前提

- Docker / Docker Compose が使えること
- x86 / arm環境対応

## 最短起動手順

### 1. 設定ファイルを用意

```bash
cp .env.example .env
cp .env.secrets.example .env.secrets
```

### 2. イメージをビルド

```bash
docker compose build
```

### 3. DB 定義を初期化

PleasanterのDB関係のマイグレーションを行う。

```bash
docker compose run --rm codedefiner _rds /y /l "ja" /z "Asia/Tokyo"
```

### 4. Pleasanter を起動

```bash
docker compose up -d
```

### 5. 動作確認

ブラウザで以下を開きます。

- `http://localhost:50001/`

初期ログイン情報:

| ユーザ          | パスワード   |
| --------------- | ------------ |
| `Administrator` | `pleasanter` |

## 詳細ドキュメント

- [構成と全体図](./doc/architecture.md)
- [設定ファイル](./doc/configuration.md)
- [開発環境](./doc/development.md)
- [SSL で起動する](./doc/ssl.md)
- [バックアップ / 復元手順](./doc/backup-restore.md)
- [pg_dumpall 復元手順](./doc/pg-dumpall-restore.md)
- [PITR 復元手順](./doc/pitr-restore.md)

S3 同期の有効化条件や `sync_to_s3.sh` の動きも、[バックアップ / 復元手順](./doc/backup-restore.md) にまとめています。

## 参考

- [Pleasanter 公式: Dockerで起動する](https://pleasanter.org/ja/manual/getting-started-pleasanter-docker)
- [Qiita: pleasanter+PostgreSQL+SSL+docker な構成を作ってみた](https://qiita.com/yamada28go/items/b9e6acdb4cca9572c7a6)
- [Qiita: Dockerでバックアップを含む Pleasanter + PostgreSQL 環境を組んでみた](https://qiita.com/yamada28go/items/fe8f85305d388ad30a60)
- [HTTPS-PORTAL 公式 README](https://github.com/SteveLTN/https-portal)
