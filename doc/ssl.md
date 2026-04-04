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

## 2. HTTPS 側で国単位のアクセス制限を使う場合

`https-portal` では `CUSTOM_NGINX_GLOBAL_HTTP_CONFIG_BLOCK` と `CUSTOM_NGINX_SERVER_CONFIG_BLOCK` を使って、Nginx の `geo` 変数によるアクセス制限を追加できます。

このリポジトリでは、通常の HTTPS 設定は [`docker-compose.https-portal.yml`](../docker-compose.https-portal.yml)、日本向け IP 制限の追加設定は [`docker-compose.https-portal.geo.yml`](../docker-compose.https-portal.geo.yml) に分けています。

`docker-compose.https-portal.geo.yml` では、次の volume を追加します。

```yaml
volumes:
  - ./images/steveltn/https-portal/jp.nginx-geo.txt:/var/lib/https-portal/jp.nginx-geo.txt:ro
```

`jp.nginx-geo.txt` は `geo $ipv4_jp { ... }` まで含んだ complete な Nginx 設定片です。この構成では `https://ipv4.fetus.jp/jp.nginx-geo.txt` をそのまま配置し、日本の IPv4 レンジを `$ipv4_jp` として読み込む前提にしています。

`docker-compose.https-portal.geo.yml` では、概ね次のような設定を入れています。

```yaml
environment:
  CUSTOM_NGINX_GLOBAL_HTTP_CONFIG_BLOCK: |
    include /var/lib/https-portal/jp.nginx-geo.txt;
  CUSTOM_NGINX_SERVER_CONFIG_BLOCK: |
    if ($$ipv4_jp = 0) {
      return 403;
    }
```

これにより HTTPS 側では `$ipv4_jp = 1` のアクセスだけを通し、それ以外は 403 にします。Compose 上では `$` を環境変数展開から守るため、`$$` で書く必要があります。

`CUSTOM_NGINX_SERVER_PLAIN_CONFIG_BLOCK` ではなく `CUSTOM_NGINX_SERVER_CONFIG_BLOCK` だけを使っているのは、Let's Encrypt の HTTP-01 検証を壊さないためです。HTTP 側まで同じ制限を掛けると、証明書更新時の `/.well-known/acme-challenge/` が失敗する可能性があります。

日本向けの `jp.nginx-geo.txt` を更新する場合は、[`scripts/make_ip_filter.sh`](../scripts/make_ip_filter.sh) を使えます。

```bash
./scripts/make_ip_filter.sh
```

このスクリプトは次を行います。

- `https://ipv4.fetus.jp/jp.nginx-geo.txt` を取得する
- `images/steveltn/https-portal/jp.nginx-geo.txt` に出力する

必要なら出力先ディレクトリ、ファイル名、取得元 URL は引数で上書きできます。

```bash
./scripts/make_ip_filter.sh /path/to/output jp.nginx-geo.txt https://ipv4.fetus.jp/jp.nginx-geo.txt
```

利用上の注意:

- `ipv4.fetus.jp` の案内では、自動アクセス自体は想定内ですが、データベース更新は原則 1 日 1 回です。短い間隔で cron 実行しても意味が薄いので、実行頻度は抑えてください
- 毎時 0 分頃はダウンロードが集中しやすいと案内されています。定期取得するなら、その時間帯を避けて分散した方が安全です
- 取得データが空だったり、想定より欠けていた過去事例があると案内されています。更新後は `jp.nginx-geo.txt` が空になっていないかを確認してください
- 公式案内では、自動アクセス時は可能な限り User-Agent に連絡先を入れてほしいとされています。高頻度運用や継続運用をするなら、この点も検討してください

補足:

- `jp.nginx-geo.txt` は `dynamic-env` ではないため、ファイル更新だけでは `https-portal` が自動再読込しない可能性があります。確実に反映するなら `docker compose restart https-portal` を実行してください
- 公式 README では、Docker Desktop for Mac / Windows では送信元 IP がプロキシ側 IP に見えるため、期待通り動かない場合があると案内されています
- STG / 本番のような Linux ホスト上の Docker で使う前提なら、この方式が扱いやすいです

## 3. HTTPS 用サービスを含めて起動

通常の HTTPS 起動:

```bash
docker compose -f docker-compose.yml -f docker-compose.https-portal.yml up -d
```

日本向け IP 制限も有効にする場合:

```bash
docker compose -f docker-compose.yml -f docker-compose.https-portal.yml -f docker-compose.https-portal.geo.yml up -d
```

## 4. アクセス確認

ブラウザで以下へアクセスします。

- `https://<あなたのドメイン>/`

補足:

- Let's Encrypt のドメイン認証のため、80 番ポートも必要です
- 証明書再取得が必要な場合は `FORCE_RENEW: "true"` を一時的に使います
- 大きなファイルを扱う場合は `CLIENT_MAX_BODY_SIZE` を調整します
- `dynamic-env` 配下の環境変数ファイル変更は通常 1 秒程度で反映されます
