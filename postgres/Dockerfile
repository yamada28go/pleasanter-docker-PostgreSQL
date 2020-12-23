FROM postgres:12-alpine
ENV LANG ja_JP.utf8

# バックアップ用のディレクトリを生成しておく
RUN mkdir -p /var/lib/postgresql/arclog/ &&\
    chmod 777 /var/lib/postgresql/arclog/
