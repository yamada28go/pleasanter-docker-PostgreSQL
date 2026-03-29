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

## 2. HTTPS 用サービスを含めて起動

```bash
docker compose -f docker-compose.yml -f docker-compose.https-portal.yml up -d
```

## 3. アクセス確認

ブラウザで以下へアクセスします。

- `https://<あなたのドメイン>/`

補足:

- Let's Encrypt のドメイン認証のため、80 番ポートも必要です
- 証明書再取得が必要な場合は `FORCE_RENEW: "true"` を一時的に使います
- 大きなファイルを扱う場合は `CLIENT_MAX_BODY_SIZE` を調整します
