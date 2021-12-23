#!/bin/bash
export LANG=ja_JP.UTF-8

# パラメータファイルの調整を行う
# 既存のファイルを書き出しておく
rsync -rv --delete /home/Pleasanter.NetCore/Implem.Pleasanter.NetCore/App_Data/Parameters_back/* /var/opt/parameters/raw
# 変更分だけ取り込む
rsync -rv /var/opt/parameters/customize/* /home/Pleasanter.NetCore/Implem.Pleasanter.NetCore/App_Data/Parameters
cd `dirname $0`
cd ../publish/Implem.Pleasanter/
dotnet Implem.Pleasanter.NetCore.dll --urls=http://0.0.0.0:80 --pathbase=/pleasanter
