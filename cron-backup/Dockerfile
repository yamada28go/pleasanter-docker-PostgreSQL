FROM debian:trixie-slim
USER root

# pg_rmanの設定
ARG RMAN_VER=V1.3.19
ARG PG_VER=18

# 日本時間に設定
ENV TZ=Asia/Tokyo

# cronを入れる
RUN apt-get update && apt-get -y install busybox-static nkf

# cron設定をコピー
COPY ./config/crontab /var/spool/cron/crontabs/root
RUN nkf -Lu --overwrite /var/spool/cron/crontabs/root

# Postgress クライアントをインストール
RUN apt-get update && \
  apt-get install -y lsb-release wget gnupg2 ca-certificates && \
  wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor -o /usr/share/keyrings/postgresql.gpg
RUN echo "deb [signed-by=/usr/share/keyrings/postgresql.gpg] http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list && \
  apt-get update && \
  apt-get install -y postgresql-client-${PG_VER}

# バックアップに使用するツール
RUN apt-get -y install p7zip-full bc

# pg_rmanのビルドツールをインストール
WORKDIR /root
RUN apt update &&\
  apt-get install -y gcc make libpq-dev zlib1g-dev libpam0g-dev libssl-dev libselinux1-dev libkrb5-dev libedit-dev postgresql-server-dev-${PG_VER} git libzstd-dev liblz4-dev libreadline-dev libnuma-dev
# Release zipだとビルド出来なくなっていたので、
# gitからtag指定で取得する
RUN mkdir pg_rman_git &&\
  cd pg_rman_git &&\
  git clone https://github.com/ossc-db/pg_rman.git &&\
  cd pg_rman &&\
  if [ "${PG_VER}" = "18" ]; then \
    git checkout master; \
  else \
    git checkout ${RMAN_VER}; \
  fi &&\
  make LDFLAGS="-L/usr/lib/postgresql/${PG_VER}/lib" &&\
  make install

# S3用自動バックアップ用にAWS　CLIをインストール
RUN apt update &&\
  apt-get install -y curl unzip less 

# AWS CLIのコマンドはアーキテクチャによって異なるので、アーキテクチャによって分岐する
RUN if [ `dpkg --print-architecture` = "arm64" ]; then \
      curl "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "awscliv2.zip"; \
    else \
      curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"; \
    fi 
RUN  unzip awscliv2.zip &&\
  ./aws/install &&\
  /usr/local/bin/aws --version

# キャッシュを消去
RUN apt-get -y clean \
  && rm -rf /var/lib/apt/lists/*

# postgressのバックアップ設定
WORKDIR /root
# バックアップ関連スクリプトをまとめて配置する
COPY ./shell/ /var/backup_sh/

# 改行コードを統一し、シェルスクリプトへ実行権限を付与する
RUN find /var/backup_sh -type f \( -name "*.sh" -o -name "*.sql" \) -exec nkf -Lu --overwrite {} \; && \
  find /var/backup_sh -type f -name "*.sh" -exec chmod +x {} \;

CMD busybox crond -l 2 -L /dev/stderr -f
