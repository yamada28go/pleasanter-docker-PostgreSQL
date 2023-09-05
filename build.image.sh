#!/bin/bash

# ---
# プリザンターのローカルイメージ生成スクリプト
#
# 使用例
# ./build.image.sh 1.3.46.0
#

Pleasanter_Ver="1.3.46.0"

# 引数が1つ以上でない場合にエラーメッセージを表示する関数
check_arguments() {
    if [ $# -lt 1 ]; then
        echo "エラー: 引数が不足しています。少なくとも1つの引数が必要です。引数にはPleasanterのリリースバージョンを指定してください。"
        echo "例 : ./build.image.sh 1.3.46.0"
        exit 1
    fi
}

# 引数チェックを実行
check_arguments "$@"

# 第一引数を表示
Pleasanter_Ver=$1

# -----
# --- 展開準備

# 一時ディレクトリを作成
temp_dir=$(mktemp -d)
echo ${temp_dir}

# 一時ディレクトリに移動
cd "$temp_dir"

# ファイルのURLを指定
file_url="https://github.com/Implem/Implem.Pleasanter/archive/refs/tags/Pleasanter_${Pleasanter_Ver}.zip"

# ファイルを一時ディレクトリにダウンロード
wget "$file_url"

# -----
# --- ファイルを展開する

# basenameコマンドを使用してファイル名を取得
file_name=$(basename "$file_url")
echo "ファイル名: $file_name"
unzip $file_name

# -----
# --- 展開先に移動

# カレントディレクトリ内のフォルダを取得してリストに格納
folders=($(find . -maxdepth 1 -type d -not -name '.' -exec basename {} \;))

# フォルダの数が0の場合、メッセージを表示して終了
if [ ${#folders[@]} -eq 0 ]; then
    echo "カレントディレクトリにフォルダが存在しません。"
    exit 1
fi

folder_name=${folders[0]}
cd "$folder_name"

# -----
# --- イメージのビルド

# イメージを削除する
docker rmi pleasanter-local-web:${Pleasanter_Ver}
docker rmi pleasanter-local-codedefiner:${Pleasanter_Ver}

# イメージをビルドする
docker build . -t pleasanter-local-web:${Pleasanter_Ver} -f Implem.Pleasanter/Dockerfile --no-cache
docker build . -t pleasanter-local-codedefiner:${Pleasanter_Ver} -f Implem.CodeDefiner/Dockerfile --no-cache

# 一時ディレクトリを後始末（削除）
rm -r "$temp_dir"

echo "イメージビルド完了!"
echo "pleasanter-local-web:${Pleasanter_Ver}"
echo "pleasanter-local-web:${Pleasanter_Ver}"

