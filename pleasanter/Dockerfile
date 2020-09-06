FROM mcr.microsoft.com/dotnet/core/sdk:3.1-buster
USER root

# ビルド対象とするgitのHash値
ARG GIT_HASH

# 必要なツールをビルド
WORKDIR /tmp
RUN apt update \
	&& apt install -y \
	apt-utils\
	git \
	curl \
	supervisor \
	locales \
	tzdata
RUN apt-get clean \
	&& rm -rf /var/apt/cache/* /tmp/* /var/tmp/* \
	&& locale-gen ja_JP.UTF-8

# 対象となるコードを取得
RUN git clone https://github.com/implem/implem.Pleasanter.NetCore /home/Pleasanter.NetCore
WORKDIR /home/Pleasanter.NetCore
RUN git checkout ${PARAMETER}

WORKDIR /home/Pleasanter.NetCore
COPY supervisord.conf /usr/local/etc/supervisord.conf
COPY Rds.json Implem.Pleasanter.NetCore/App_Data/Parameters/Rds.json
COPY pleasanter.sh cmdnetcore/pleasanter.sh
RUN chmod 744 cmdnetcore/*.sh \
	&& cmdnetcore/build.sh

# Fix
# Linuxでビルドする場合、必要なファイルがコピーされなていので修正
RUN cp -a Implem.Pleasanter/wwwroot/bundles publish/Implem.Pleasanter/wwwroot/

RUN echo 'export LANG=ja_JP.UTF-8' >> ~/.bashrc

EXPOSE 80 1433
CMD ["/usr/bin/supervisord", "-n", "-c", "/usr/local/etc/supervisord.conf"]
