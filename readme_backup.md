## これは何

データをバックアップ、リストアするための方法一覧です。
この環境設定ば、バックアップ

### Backupの方式

本コンテナ構成では2種類のバックアップ方式を使ってデータを保全するように設定されています。
それぞれのバックアップ方式に関しては下記に示します。

| 種別 | 概要 |メリット|デメリット|
|:-----------|:------------|:------------|:------------|
| 全バックアップ   | バックアップがSQL形式になるので復元が簡単|時間がかかる。容量が多い| BDに対してFull Backupを実行       | 
|  PITR   |早い。必要とされる容量が差分だけ。| 完全な復元に手間がかかる。 | PITR( (Point In Time Recovery) )を実行   | 


### バックアップの取得頻度

バックの動作管理はcronにより制御されています。
該当cromの設定は「cron-backup\config\crontab」にあります。
初期状態では以下の指定になっています。
必要に応じて、対象時間を切り替えてください。

| 種別 | 頻度 |
|:-----------|:------------|
|全バックアップ|毎日午前0時に1回|
|PITR(ポイント・イン・タイム・リカバリ)|30分毎|

### ローカル環境におけるバックアップの保持期間

本構成では長期的なデータの保管はAWS S3を使用する事を前提としています。
このため、ローカル環境におけるバックアップデータの保持期間は必要最低限となるように設定されています。
バックアップ期間を変更したい場合、後述のバックアップスクリプト上の定義を修正してください。

| 種別 | 頻度 |
|:-----------|:------------|
|全バックアップ|1日間|
|PITR(ポイント・イン・タイム・リカバリ)|1日間|


### ディレクトリ構成
pcron-backupコンテナから見たディレクトリ構成が下表となります。
共有が〇となっているパスに関してはpostgres-dbコンテナと共有しています。

バックアップ結果のデータは「/var/db_backup」に集まってくるように出来ています。
このため、このディレクトリをコンテナ外の接続してバックアップを取得しておけば必要なコンテナの外側からバックアップは取れる状態になります。

| パス名 | 概要 |コンテナ間共有 |
|:-----------|:------------|:------------|
| /var/db_backup/PITR/       |    ポイント・イン・タイム・リカバリ用のバックアップ結果保持ディレクトリ    | |
| /var/db_backup/dumpall     | 全データバックアップ結果保持ディレクトリ      | |
| /var/backup_sh| バックアップ用Shell格納ディレクトリ        | |
| /var/| バックアップ用Shell格納ディレクトリ        | |
| /var/lib/postgresql/data/|   postgresqlデータ領域    |〇  | 
| /var/lib/postgresql/arclog| postgresqlWAL領域       | 〇| 




----

## バックアップ

バックアップ処理は「cron-backup」コンテナに入って実施します。

### 完全バックアップ

以下コマンドで完全バックアップを取得する事ができます。

```
flock --timeout=600 /tmp/db_backup.lock /var/backup_sh/pg_dumpall.sh
```

### PITR

#### 概要

PITR(ポイント・イン・タイム・リカバリ)を実施するために、
pg_rmanを使用します。
PITRでは、基本となるフルバックアップと、フルバックアップからの差分を取得する差分バックアップが存在します。

#### フルバックアップ

基本となるフルバックアップを取得します。

```
flock --timeout=300 /tmp/db_backup.lock /var/backup_sh/pg_rman.sh FULL
```

#### 差分バックアップ

差分バックアップを取得します。
事前にPITRのフルバックアップを取得している必要があります。

```
flock --timeout=300 /tmp/db_backup.lock /var/backup_sh/pg_rman.sh INCREMENTAL
```

---

## リストア

### 完全バックアップ

CodeDefinerをかける前の状態を指定する。


dbコンテナにバックアップファイルをマウントする。
該当ファイルをリストアする。


```
 psql -h postgres-db -p 5432  -U postgres -f backup
```
 psql -h postgres-db -p 5432  -U postgres -f backup


### PITR

#### 概要

PITRは指定された任意時間へのデータ復元か゛可能なバックアップ方式となります。
本システムでは、30分ごとにチェックポイントを設けてスナップショットを取得しています。

#### 復元対象の絞り込み

復元可能なバックアップポイントは以下コマンドで取得する事ができます。

```
source /var/backup_sh/pg_rman_env.sh
pg_rman show
```

実行例を以下に示します。
実行時間を指定する時は、「EndTime」の値を指定するようにします。

```
root@ec31ec17632a:~# pg_rman show
=====================================================================
 StartTime           EndTime              Mode    Size   TLI  Status 
=====================================================================
2023-06-18 15:00:53  2023-06-18 15:00:55  FULL  4290kB     1  OK
2023-06-18 15:00:46  2023-06-18 15:00:48  FULL  4343kB     1  OK
2023-06-18 15:00:00  2023-06-18 15:00:03  FULL  7601kB     1  OK
root@ec31ec17632a:~# 
```

#### 復元の実行

復元は以下コマンドで実行する事ができます。
前述したとおり、復元時間は一覧に表示されたデータのうち「EndTime」を指定してください。

```
source /var/backup_sh/pg_rman_env.sh
pg_rman restore  --recovery-target-time '2023-06-18 15:00:03' 
```

#### 設定ファイルの復元

コマンドが実行されると必用なデータが復元されます。
そのとき、次回のpostgres起動時に必用な設定値が以下パスのファイルに書き込まれます。
以下コマンドで出力された内容を確認します。

```
cat /var/lib/postgresql/data/pg_rman_recovery.conf
```

概要ファイルの内容例は以下となります。

```
# added by pg_rman 1.3.15
restore_command = 'cp /var/lib/postgresql/arclog/%f %p'
recovery_target_time = '2023-06-18 15:00:03'
recovery_target_timeline = '3'
```

#### DB起動設定の指定

```postgresql.conf```ファイルの最後に以下に、
作成されたコマンドを追記します。

```postgresql.conf```ファイルはcomposeファイルで指定したものとなります。

指定する時に注意する事があります。
```postgresql.conf```ファイルにおいて、**「リカバリ時間の指定はUTCである必用がある」**というポイントです。
pg_rmanで出力された値をそのまま指定すると、望んだ時刻でデータが復元されないので、
注意が必要です。

以下が設定例です。
時刻にたいして**「+09」**を追加しています。

```
# added by pg_rman 1.3.15
restore_command = 'cp /var/lib/postgresql/arclog/%f %p'
recovery_target_time = '2023-06-18 15:00:03+09'
recovery_target_timeline = '3'
```

#### DB起動

DBコンテナを起動します。
コンテナを起動すると自動的にリカバリ動作が起動します。
以下がリカバリログの例です。


```
023-06-18 16:08:17 2023-06-18 07:08:17.002 GMT [1] LOG:  listening on IPv4 address "0.0.0.0", port 5432
2023-06-18 16:08:17 2023-06-18 07:08:17.002 GMT [1] LOG:  listening on IPv6 address "::", port 5432
2023-06-18 16:08:17 2023-06-18 07:08:17.006 GMT [1] LOG:  listening on Unix socket "/var/run/postgresql/.s.PGSQL.5432"
2023-06-18 16:08:17 2023-06-18 07:08:17.013 GMT [25] LOG:  database system was interrupted; last known up at 2023-06-18 06:00:00 GMT
2023-06-18 16:08:17 2023-06-18 07:08:17.101 GMT [25] LOG:  restored log file "00000005.history" from archive
2023-06-18 16:08:17 2023-06-18 07:08:17.101 GMT [25] LOG:  starting point-in-time recovery to 2023-06-18 06:00:03+00
2023-06-18 16:08:17 2023-06-18 07:08:17.102 GMT [25] LOG:  restored log file "00000005.history" from archive
2023-06-18 16:08:17 2023-06-18 07:08:17.126 GMT [25] LOG:  restored log file "000000010000000000000004" from archive
2023-06-18 16:08:17 2023-06-18 07:08:17.203 GMT [25] LOG:  restored log file "00000002.history" from archive
2023-06-18 16:08:17 2023-06-18 07:08:17.208 GMT [25] LOG:  restored log file "00000003.history" from archive
2023-06-18 16:08:17 2023-06-18 07:08:17.213 GMT [25] LOG:  restored log file "00000004.history" from archive
2023-06-18 16:08:17 2023-06-18 07:08:17.222 GMT [25] LOG:  redo starts at 0/4000028
2023-06-18 16:08:17 2023-06-18 07:08:17.251 GMT [25] LOG:  restored log file "000000010000000000000005" from archive
2023-06-18 16:08:17 2023-06-18 07:08:17.402 GMT [25] LOG:  consistent recovery state reached at 0/4000100
2023-06-18 16:08:17 2023-06-18 07:08:17.402 GMT [1] LOG:  database system is ready to accept read-only connections
2023-06-18 16:08:17 2023-06-18 07:08:17.454 GMT [25] LOG:  restored log file "000000010000000000000006" from archive
2023-06-18 16:08:17 2023-06-18 07:08:17.601 GMT [25] LOG:  restored log file "000000050000000000000007" from archive
2023-06-18 16:08:18 2023-06-18 07:08:18.234 GMT [25] LOG:  recovery stopping before commit of transaction 847, time 2023-06-18 06:54:25.746006+00
2023-06-18 16:08:18 2023-06-18 07:08:18.234 GMT [25] LOG:  pausing at the end of recovery
2023-06-18 16:08:18 2023-06-18 07:08:18.234 GMT [25] HINT:  Execute pg_wal_replay_resume() to promote.
```

以下のように表示されれば処理登録き成功となります。

```
pausing at the end of recovery
```

#### ポースの解除

DBの復元が完了した状態では、
DBは外部からのアクセスがロックされた状態になっています。
そこで、以下コマンドを実行する事がdbへのロックが解除されてアクセスができるようになります。

```
psql  -U postgres -c "SELECT pg_wal_replay_resume();"
```

####　バックアップ

復元が完了し、復元データが正しく戻っていることが確認できたら、
DBの完全バックアップを取得してください。

####　設定ファイルを戻す

```postgresql.conf```ファイルの最後に以下に追加したリストア関係のデータを削除します。
(基本的には、gitにある編集前の値に戻せばOK。)


## 参考
[【PostgreSQL 12】指定した時間までリカバリするPITR](https://qiita.com/yaju/items/51e7b1037a99856e547c)
[PostgreSQL の PITR で指定できるタイムスタンプの形式](https://blog.manabusakai.com/2014/03/postgresql-pitr/)
[PostgreSQL 13 PITR(Point In Time Recovery)基本概念の説明](https://changineer.info/server/postgresql/postgresql_backup_pitr01.html)

