#!/usr/bin/env bash

# 取得元の ipv4.fetus.jp は自動アクセスを許容していますが、
# 更新は原則 1 日 1 回のため高頻度実行は避け、毎時 0 分頃も外してください。
# また、空データや欠損データの可能性があるため、出力結果は必ず確認してください。

set -euo pipefail

URL="${3:-https://ipv4.fetus.jp/jp.nginx-geo.txt}"
OUTPUT_DIR="${1:-images/steveltn/https-portal}"
OUTPUT_FILE_NAME="${2:-jp.nginx-geo.txt}"
OUTPUT_FILE="${OUTPUT_DIR}/${OUTPUT_FILE_NAME}"
TEMP_DIR="$(mktemp -d /tmp/make_ip_filter.XXXXXX)"
TEMP_FILE="${TEMP_DIR}/source.txt"

cleanup() {
	rm -rf "${TEMP_DIR}"
}

trap cleanup EXIT

mkdir -p "${OUTPUT_DIR}"

curl -fsSL -o "${TEMP_FILE}" "${URL}"

if [[ ! -s "${TEMP_FILE}" ]]; then
	echo "Downloaded file is empty: ${URL}" >&2
	exit 1
fi

mv "${TEMP_FILE}" "${OUTPUT_FILE}"

echo "Geo filter written to ${OUTPUT_FILE}"
