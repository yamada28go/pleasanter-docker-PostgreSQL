FROM debian:trixie-slim AS base
USER root

# pg_rmanの設定
ARG PG_RMAN_VERSION=V1.3.19
ARG POSTGRES_VERSION=18

# 日本時間に設定
ENV TZ=Asia/Tokyo
ENV PG_VER=${POSTGRES_VERSION}

RUN apt-get update && \
  apt-get install -y lsb-release wget gnupg2 ca-certificates && \
  wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor -o /usr/share/keyrings/postgresql.gpg && \
  echo "deb [signed-by=/usr/share/keyrings/postgresql.gpg] http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list

FROM base AS builder

# pg_rmanのビルドに必要な開発ツールだけを入れる
RUN apt-get update && \
  apt-get install -y gcc make libpq-dev zlib1g-dev libpam0g-dev libssl-dev libselinux1-dev libkrb5-dev libedit-dev postgresql-server-dev-${PG_VER} git libzstd-dev liblz4-dev libreadline-dev libnuma-dev

WORKDIR /root

# Release zipだとビルド出来なくなっていたので、gitから取得する
RUN mkdir pg_rman_git && \
  cd pg_rman_git && \
  git clone https://github.com/ossc-db/pg_rman.git && \
  cd pg_rman && \
    git checkout ${PG_RMAN_VERSION}; \
  make LDFLAGS="-L/usr/lib/postgresql/${PG_VER}/lib" && \
  make install

FROM base

# cronとバックアップ実行に必要なツールだけを入れる
RUN apt-get update && \
  apt-get install -y busybox-static nkf postgresql-client-${PG_VER} p7zip-full bc curl unzip less libpq5 libnuma1 && \
  ln -sf /bin/busybox /usr/local/bin/crontab && \
  rm -rf /var/lib/apt/lists/*

# builderで生成したpg_rmanバイナリを引き継ぐ
COPY --from=builder /usr/lib/postgresql/${PG_VER}/bin/pg_rman /usr/lib/postgresql/${PG_VER}/bin/pg_rman

# cron設定をコピー
COPY ./config/crontab /var/spool/cron/crontabs/root
RUN nkf -Lu --overwrite /var/spool/cron/crontabs/root

# S3用自動バックアップ用にAWS CLIをインストール
WORKDIR /root
RUN if [ "$(dpkg --print-architecture)" = "arm64" ]; then \
      curl "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "awscliv2.zip"; \
    else \
      curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"; \
    fi && \
  unzip awscliv2.zip && \
  ./aws/install && \
  /usr/local/bin/aws --version && \
  rm -rf aws awscliv2.zip

# postgressのバックアップ設定
WORKDIR /root
# バックアップ関連スクリプトをまとめて配置する
COPY ./shell/ /var/backup_sh/

# 改行コードを統一し、シェルスクリプトへ実行権限を付与する
RUN find /var/backup_sh -type f \( -name "*.sh" -o -name "*.sql" \) -exec nkf -Lu --overwrite {} \; && \
  find /var/backup_sh -type f -name "*.sh" -exec chmod +x {} \;

CMD busybox crond -l 2 -L /dev/stderr -f
