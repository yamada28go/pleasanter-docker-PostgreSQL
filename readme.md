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

### 3. DBを初期化する

作成した設定でコンテナを起動します。
これにより、上記の環境設定でpostgresが初期化されます。
dbコンテナはバックグラウンドで起動します。

```
docker compose up postgres-db -d
```

``` 
docker-compose down --volumes --remove-orphans && docker compose up postgres-db 
```

### 4. プリザンターのDB定義を初期化する

先にビルドしたイメージを使って、dbにプリザンターの環境を作ります。
以下コマンドを実行すると必用なテーブルが生成されます。

```
docker-compose run codedefiner _rds
```

### 5. プリザンターを起動する


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
