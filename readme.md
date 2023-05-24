**これは何**

オープンソースWebDB [プリザンター](https://github.com/Implem/Implem.Pleasanter) を、簡単に起動できるようシングルコンテナにまとめたComposeです。
詳細な使い方に関しては[Quiita](https://qiita.com/yamada28go/items/b9e6acdb4cca9572c7a6)の記事を参照してください。

**参考**
[Pleasanterをサクッと起動できるcompose](https://qiita.com/coleyon/items/8ca7830cdb0515f370de)
[Docker上で動かしてみた公式記事](https://pleasanter.hatenablog.jp/entry/2019/04/08/191954)

----

## 使い方

[Pleasanter](https://github.com/Implem/Implem.Pleasanter/releases)

### 

```
docker build . -t pleasanter-local-web:1.3.38.1 -f Implem.Pleasanter/Dockerfile --no-cache
```

```
docker build . -t pleasanter-local-codedefiner:1.3.38.1 -f Implem.CodeDefiner/Dockerfile --no-cache
```

初期テーブルを設定する

```
docker compose run Implem.CodeDefiner _rds
```