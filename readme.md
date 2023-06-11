## これは何

オープンソースWebDB [プリザンター](https://github.com/Implem/Implem.Pleasanter) を、簡単に起動できるようシングルコンテナにまとめたComposeです。
詳細な使い方に関しては[Quiita](https://qiita.com/yamada28go/items/b9e6acdb4cca9572c7a6)の記事を参照してください。

### 特徴
vpsのような環境で簡単にPleasanterが起動して運用できるように整備してあります。



----

## 使い方

[Pleasanter](https://github.com/Implem/Implem.Pleasanter/releases)

### 1. ダウンロード

まずは、[Pleasanter](https://github.com/Implem/Implem.Pleasanter/releases)を取得します。

複数のファイルがありますが、ソースコードを取得してください。

### 2. Pleasanterのビルド
プリザンターをビルドします。
ローカルで使用するバージョンを指定しておきます。

```
docker build . -t pleasanter-local-web:1.3.40.1 -f Implem.Pleasanter/Dockerfile --no-cache
```

```
docker build . -t pleasanter-local-codedefiner:1.3.40.1 -f Implem.CodeDefiner/Dockerfile --no-cache
```

### 3. 環境変数の設定

接続設定用に環境変数を定義します。
docker-compose.ymlファイルが存在するディレクトリと同じディレクトリに「.env」ファイルを作成してください。
dockerか起動するときに、同ファイル内の定義を読み込んで起動します。

```  
# postgresの設定
POSTGRES_USER=postgres
POSTGRES_PASSWORD=mysecretpassword1234
POSTGRES_DB=Implem.Pleasanter
POSTGRES_HOST_AUTH_METHOD=scram-sha-256
POSTGRES_INITDB_ARGS="--auth-host=scram-sha-256"

#dockerの設定
Implem_Pleasanter_Rds_PostgreSQL_SaConnectionString='Server=postgres-db;Database=postgres;UID=postgres;PWD=mysecretpassword1234'
Implem_Pleasanter_Rds_PostgreSQL_OwnerConnectionString='Server=postgres-db;Database=#ServiceName#;UID=#ServiceName#_Owner;PWD=mysecretpassword1234'
Implem_Pleasanter_Rds_PostgreSQL_UserConnectionString='Server=postgres-db;Database=#ServiceName#;UID=#ServiceName#_User;PWD=mysecretpassword1234'

```

設定の中で定義が必用な内容は以下となります。
パスワードは環境に任意に変更してください。

| Variable            | Value                |意味|
|---------------------|----------------------|---|
| POSTGRES_USER       | postgres             |postgresのユーザー名|
| POSTGRES_PASSWORD   | mysecretpassword1234 |postgresのパスワード|


### 3. DBを初期化する

作成した設定でコンテナを起動します。
これにより、上記の環境設定でpostgresが初期化されます。

```
docker compose up postgres-db
```

### 4. プリザンターのDB定義を初期化する

先にビルドしたイメージを使って、dbにプリザンターの環境を作ります。
このとき、「postgres-db」コンテナは動作している必用があります。


```shell
docker run --rm \
    --network pleasanter-docker-postgresql_pleasanter-service-network \
    --name codedefiner \
    --env-file .env \
    pleasanter-local-codedefiner:1.3.40.1 _rds
```



```
docker compose run pleasanter-local-codedefiner:1.3.40.1 _rds
```




   ```shell
   docker run --rm --network pleasanter-service-network \
       --name codedefiner \
       --env-file env-list \
       implem/pleasanter:codedefiner _rds
   ```

## 参考
[Pleasanterをサクッと起動できるcompose](https://qiita.com/coleyon/items/8ca7830cdb0515f370de)
[Docker上で動かしてみた公式記事](https://pleasanter.hatenablog.jp/entry/2019/04/08/191954)
