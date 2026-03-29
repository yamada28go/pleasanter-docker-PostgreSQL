## これは何

オープンソースWebDB [プリザンター](https://github.com/Implem/Implem.Pleasanter) を、簡単に起動できるようシングルコンテナにまとめたComposeです。
詳細な使い方に関しては[Quiita](https://qiita.com/yamada28go/items/b9e6acdb4cca9572c7a6)の記事を参照してください。

### 特徴
vpsのような環境で簡単にPleasanterが起動して運用できるように整備してあります。


----

## 使い方

[Pleasanter](https://github.com/Implem/Implem.Pleasanter/releases)


### 3. 環境変数の設定

#### 3.1. postgresユーザーの話

少しややこしいのですが、pleasanterが動作するためには、postgresのユーザー(ロール)は3種類必用です。
以下に、各ロールの設定を示します。

| id | 種別    | 意味                     | 名称                    | パスワード                |設定場所|
| -- | ------- | ----------------------- | ----------------------- | ------------------------- |---|
| 1  | SA      | postgresの管理者         | postgres                | mysecretpassword1234_sa  |.env|
| 2  | Owner   | スキーマを保持するユーザー | Implem.Pleasanter_Owner | mysecretpassword1234_owner |.env , postgres/init/1_create.sql|
| 3  | User    | スキーマを使用するユーザー | Implem.Pleasanter_User  | mysecretpassword1234_user  |.env|

今回の環境において、これら変数の設定箇所は複数のファイルに分かれています。
Ownerだけ複数環境に分かれているため設定箇所に注意しましょう。

実際の運用時には、パスワードは任意の値に変更してください。


`.env`

```env
POSTGRES_VERSION=18
POSTGRES_VOLUMES_TARGET=/var/lib/postgresql/data
POSTGRES_ARCLOG_PATH=/var/lib/postgresql/arclog
POSTGRES_USER=postgres
POSTGRES_DB=postgres
POSTGRES_HOST_AUTH_METHOD=scram-sha-256
POSTGRES_INITDB_ARGS="--auth-host=scram-sha-256"
BACKUP_DB_HOST=postgres-db
BACKUP_DB_PORT=5432
BACKUP_DB_USER=postgres
PLEASANTER_VERSION=latest
POSTGRES_LISTEN_ADDRESSES=*
POSTGRES_ARCHIVE_MODE=on
POSTGRES_WAL_LEVEL=replica
POSTGRES_ARCHIVE_COMMAND=cp %p /var/lib/postgresql/arclog/%f
```

`.env.secrets`

```env
POSTGRES_PASSWORD=change_me
PGPASSWORD=change_me
ZIP_PASSWORD=change_me
Implem.Pleasanter_Rds_PostgreSQL_SaConnectionString=Server=postgres-db;Database=postgres;UID=postgres;PWD=change_me
Implem.Pleasanter_Rds_PostgreSQL_OwnerConnectionString=Server=postgres-db;Database=#ServiceName#;UID=#ServiceName#_Owner;PWD=change_me
Implem.Pleasanter_Rds_PostgreSQL_UserConnectionString=Server=postgres-db;Database=#ServiceName#;UID=#ServiceName#_User;PWD=change_me
```

```
docker compose build
```



### 4. プリザンターのDB定義を初期化する

先にビルドしたイメージを使って、dbにプリザンターの環境を作ります。
以下コマンドを実行すると必用なテーブルが生成されます。

```
docker compose run --rm codedefiner _rds /y /l "ja" /z "Asia/Tokyo"
```

### 5. プリザンターを起動する

```
docker compose up
```

起動が完了すると以下ポートで動作します。
ログインして確認してください。

[http://localhost:50001/](http://localhost:50001/)

デフォルト状態でのログインパスワードは以下となります。

| ユーザ     | パスワード    |
|------------|--------------|
| Administrator | pleasanter |


## 参考

[プリザンターの公式DockerイメージをComposeで動かす](https://qiita.com/imp-kawano/items/a9407d474c1dd39731d2)
[Pleasanterをサクッと起動できるcompose](https://qiita.com/coleyon/items/8ca7830cdb0515f370de)
[Docker上で動かしてみた公式記事](https://pleasanter.hatenablog.jp/entry/2019/04/08/191954)
