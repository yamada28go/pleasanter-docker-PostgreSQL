## 開発環境

Node 系ツールをローカルに入れる:

```bash
npm install
```

それ以外の主なツールを入れる:

```bash
brew install hadolint shellcheck yamllint shfmt
```

Lint:

```bash
make lint
```

Format:

```bash
make format
```

ローカルの `node_modules/.bin` に入った `markdownlint-cli2` と `prettier` は、`make lint` / `make format` から優先的に使われます。
