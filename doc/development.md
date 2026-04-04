## 開発環境

Lint / Format 用の作業コンテナをビルド:

```bash
make devtools-build
```

Lint:

```bash
make lint
```

Format:

```bash
make format
```

必要なら作業コンテナにシェルで入る:

```bash
make devtools-shell
```

`hadolint`、`shellcheck`、`yamllint`、`shfmt`、`markdownlint-cli2`、`prettier` は `devtools/Dockerfile` でまとめて入ります。ホスト側にこれらを直接インストールする必要はありません。

`make lint` の中では `docker compose config` も実行するため、作業コンテナには Docker ソケットをマウントしています。
