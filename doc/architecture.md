## 構成

このリポジトリでは、Pleasanter 本体に加えて以下をまとめて扱えます。

- PostgreSQL
- `cron-backup` コンテナによるバックアップ

## サービス一覧

- `postgres-db`
  - PostgreSQL 本体
- `pleasanter-web`
  - Pleasanter Web アプリ
- `codedefiner`
  - DB 定義の初期化用
- `cron-backup`
  - ダンプ / PITR バックアップ実行用
- `https-portal`
  - HTTPS 終端と Let's Encrypt 証明書管理用

このリポジトリでは `docker-compose.https-portal.yml` も用意しているため、公開ドメインと 80/443 ポートの条件が揃っていれば HTTPS 化を比較的簡単に追加できます。

## 全体構造

![全体構造](./image.png)

図に対応するコンテナ一覧:

| No  | コンテナ名       | 概要                                                                                                        | 定義ファイル                      |
| --- | ---------------- | ----------------------------------------------------------------------------------------------------------- | --------------------------------- |
| 1   | `https-portal`   | HTTPS 通信用。Let's Encrypt を用いた証明書取得の自動化。設定ファイルを用意済みのため HTTPS 化を追加しやすい | `docker-compose.https-portal.yml` |
| 2   | `pleasanter-web` | Pleasanter の Web システム                                                                                  | `docker-compose.yml`              |
| 3   | `postgres-db`    | PostgreSQL DB。Pleasanter が使用するデータベース                                                            | `docker-compose.yml`              |
| 4   | `cron-backup`    | バックアップ用の cron プログラムを格納                                                                      | `docker-compose.yml`              |

全体の説明:

- 本番で SSL を使う場合は `https-portal` が前段に入り、HTTPS 終端と証明書管理を担当します
- `pleasanter-web` は内部ネットワーク経由で `postgres-db` に接続し、Pleasanter のデータを読み書きします
- `cron-backup` は `postgres-db` のデータ領域とアーカイブログを参照してバックアップを作成します
- S3 バックアップを有効にした場合は、`cron-backup` から AWS S3 にバックアップを転送します

各コンテナの役割:

- `1. https-portal`
  - 本番運用で HTTPS 終端を担当します
  - 外部からの HTTPS アクセスを受けて `pleasanter-web` へ転送します
- `2. pleasanter-web`
  - ユーザーが直接利用する Pleasanter 本体です
  - 確認用途では HTTP で `localhost:50001` へ直接アクセスできます
- `3. postgres-db`
  - Pleasanter のデータを保持する PostgreSQL です
  - `pleasanter-web` と `cron-backup` から内部ネットワーク経由で参照されます
- `4. cron-backup`
  - 定期バックアップと復元補助を担当します
  - `postgres-db` のデータ領域と WAL 領域を参照し、必要に応じて S3 へも同期します

## 運用メモ

- `postgres-db` は healthcheck を持ち、`pleasanter-web` / `codedefiner` / `cron-backup` は DB ready を待って起動します
- `postgres-db` は起動前に WAL アーカイブ先ディレクトリを初期化し、アーカイブ書き込み権限を整えます
- DB ポート公開は `127.0.0.1:5432:5432` に限定しています
- `container_name` は固定していないため、同じホストで別 project 名の Compose を並行起動しやすい構成です
