## SSL で起動する

SSL 化には [../docker-compose.https-portal.yml](../docker-compose.https-portal.yml) を使います。構成としては、`https-portal` が `pleasanter-web` の前段に入り、Let's Encrypt 証明書の取得と HTTPS 終端を担当します。

## 事前条件

- 公開ドメイン名があること
- そのドメインがこのホストへ向いていること
- 80/tcp と 443/tcp が外部から到達可能なこと

## 1. `docker-compose.https-portal.yml` を修正

最低限、以下を自分の環境に合わせて変更します。

```yaml
environment:
  DOMAINS: "example.com -> http://pleasanter-web"
  STAGE: "production"
```

ポイント:

- `DOMAINS`
  - `example.com` を実際のドメインへ変更
- `STAGE`
  - コメントアウトのままだと自己署名証明書相当の動作
  - `production` を指定すると Let's Encrypt を使う

## 2. HTTPS 側で IP 制限を使う場合

`https-portal` では、`ACCESS_RESTRICTION` を使って接続元 IP を制限できます。

このリポジトリの [`docker-compose.https-portal.yml`](../docker-compose.https-portal.yml) では、次の volume を使って動的に環境変数を上書きできるようにしています。

```yaml
volumes:
  - ./dynamic-env:/var/lib/https-portal/dynamic-env
```

`dynamic-env` は `https-portal` の動的環境変数上書きディレクトリです。ディレクトリ内のファイル名が環境変数名、ファイル内容がその値として扱われ、更新後およそ 1 秒で設定が反映されます。

IP 制限だけを切り替えたい場合は、ホスト側で `dynamic-env/ACCESS_RESTRICTION` を作成します。

例:

```bash
mkdir -p dynamic-env
printf '203.0.113.10 198.51.100.0/24\n' > dynamic-env/ACCESS_RESTRICTION
```

この例では、`203.0.113.10` と `198.51.100.0/24` だけを許可します。値の書式は Nginx の `allow` 相当で、個別 IP と CIDR を空白区切りで並べられます。

設定を外す場合は、`dynamic-env/ACCESS_RESTRICTION` を空にするか削除します。

補足:

- 公式 README では、Docker Desktop for Mac / Windows では送信元 IP がプロキシ側 IP に見えるため、期待通り動かない場合があると案内されています
- STG / 本番のような Linux ホスト上の Docker で使う前提なら、この方式が扱いやすいです

## 3. HTTPS 用サービスを含めて起動

```bash
docker compose -f docker-compose.yml -f docker-compose.https-portal.yml up -d
```

## 4. アクセス確認

ブラウザで以下へアクセスします。

- `https://<あなたのドメイン>/`

補足:

- Let's Encrypt のドメイン認証のため、80 番ポートも必要です
- 証明書再取得が必要な場合は `FORCE_RENEW: "true"` を一時的に使います
- 大きなファイルを扱う場合は `CLIENT_MAX_BODY_SIZE` を調整します
- `dynamic-env/ACCESS_RESTRICTION` を変更した場合は、通常はコンテナ再起動なしで反映されます
