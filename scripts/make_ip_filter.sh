#!/usr/bin/env bash

# 取得元の ipv4.fetus.jp は自動アクセスを許容していますが、
# 更新は原則 1 日 1 回のため高頻度実行は避け、毎時 0 分頃も外してください。
# また、空データや欠損データの可能性があるため、出力結果は必ず確認してください。

set -euo pipefail

URL="https://ipv4.fetus.jp/jp.txt"
OUTPUT_DIR="${1:-images/steveltn/https-portal/dynamic-env}"
OUTPUT_FILE_NAME="${2:-ACCESS_RESTRICTION}"
OUTPUT_FILE="${OUTPUT_DIR}/${OUTPUT_FILE_NAME}"
TEMP_DIR="$(mktemp -d /tmp/make_ip_filter.XXXXXX)"
TEMP_FILE="${TEMP_DIR}/source.txt"
FILTERED_FILE="${TEMP_DIR}/${OUTPUT_FILE_NAME}"

cleanup() {
	rm -rf "${TEMP_DIR}"
}

trap cleanup EXIT

mkdir -p "${OUTPUT_DIR}"

curl -fsSL -o "${TEMP_FILE}" "${URL}"

# HTTPS-PORTAL の ACCESS_RESTRICTION は空白区切りの 1 行を想定しているため、
# コメントと空行を除去したうえで 1 行へ正規化する。
awk '
	!/^[[:space:]]*#/ && NF {
		if (count++) {
			printf " "
		}
		printf "%s", $1
	}
	END {
		printf "\n"
	}
' "${TEMP_FILE}" >"${FILTERED_FILE}"

mv "${FILTERED_FILE}" "${OUTPUT_FILE}"

echo "IP filter written to ${OUTPUT_FILE}"
