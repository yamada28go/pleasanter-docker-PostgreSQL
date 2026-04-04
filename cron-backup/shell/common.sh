#!/bin/bash

LOG_SCRIPT_NAME="${LOG_SCRIPT_NAME:-$(basename "$0")}"

log_info() {
	echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] [${LOG_SCRIPT_NAME}] $*"
}

log_warn() {
	echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARN] [${LOG_SCRIPT_NAME}] $*" >&2
}

log_error() {
	echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] [${LOG_SCRIPT_NAME}] $*" >&2
}
