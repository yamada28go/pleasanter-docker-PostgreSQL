**これは何**

オープンソースWebDB [プリザンター](https://github.com/Implem/Implem.Pleasanter) のデモを、簡単に起動できるようシングルコンテナにまとめたComposeです。
[Docker上で動かしてみた公式記事](https://pleasanter.hatenablog.jp/entry/2019/04/08/191954)の構築手順を基にしつつ、
PostgreSQLとPleasanterが、マルチコンテナで動作する構成です。

**Quick Start**

    $ docker-compose build
    $ docker-compose up -d
    $ docker exec -it $CONTAINER_ID cmdnetcore/codedefiner.sh   # 初回DB生成
    <INFO> RdsConfigurator.Configure: Implem.Pleasanter
    <INFO> LoginsConfigurator.Execute: Implem.Pleasanter_Owner
    <INFO> LoginsConfigurator.Execute: Implem.Pleasanter_User
    <INFO> TablesConfigurator.ConfigureTableSet: Tenants
    <INFO> Tables.CreateTable: Tenants
    <INFO> Tables.CreateTable: Tenants_deleted
    <INFO> Tables.CreateTable: Tenants_history
    <INFO> TablesConfigurator.ConfigureTableSet: Demos
    <INFO> Tables.CreateTable: Demos
    ...
    <SUCCESS> Starter.ConfigureDatabase: Database configuration is complete.
    <SUCCESS> Starter.Main: All of the processing has been completed.

access to ``http://localhost`` .

    user: Administrator
    pass: pleasanter

**SSL設定**

このブランチではSSL機能が有効化されています。
実施

**参考**

[Pleasanterをサクッと起動できるcompose](https://qiita.com/coleyon/items/8ca7830cdb0515f370de)


[Docker上で動かしてみた公式記事](https://pleasanter.hatenablog.jp/entry/2019/04/08/191954)

[docker で全自動 Let's encrypt](https://qiita.com/kuboon/items/f424b84c718619460c6f)

[https-portalを使ってみて、個人的にぶつかりそうな壁の解決方法](https://qiita.com/github0013@github/items/71c44d7bf4faf63c1956)