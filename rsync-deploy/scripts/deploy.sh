#!/bin/bash
# =============================================================================
# rsync-deploy - 本地代码快速同步到远端服务器工具
# 用法: ./deploy.sh [选项]
# =============================================================================

set -e

# ---- 颜色输出 ----
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}[INFO]${NC}  $1"; }
log_success() { echo -e "${GREEN}[OK]${NC}    $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC}  $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

# ---- 脚本所在目录（支持从任意位置调用）----
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF_FILE="${SCRIPT_DIR}/deploy.conf"

# ---- 加载配置文件 ----
if [ ! -f "$CONF_FILE" ]; then
    log_error "配置文件不存在: $CONF_FILE"
    log_warn  "请先复制模板并填写配置: cp deploy.conf.example deploy.conf"
    exit 1
fi

source "$CONF_FILE"

# ---- 校验必填配置 ----
: "${REMOTE_USER:?'deploy.conf 中未设置 REMOTE_USER'}"
: "${REMOTE_HOST:?'deploy.conf 中未设置 REMOTE_HOST'}"
: "${REMOTE_PATH:?'deploy.conf 中未设置 REMOTE_PATH'}"
: "${LOCAL_PATH:?'deploy.conf 中未设置 LOCAL_PATH'}"

# ---- 默认值 ----
SSH_PORT="${SSH_PORT:-22}"
SSH_KEY_OPT=""
if [ -n "$SSH_KEY" ]; then
    SSH_KEY_OPT="-i $SSH_KEY"
fi

# ---- 解析命令行参数 ----
DRY_RUN=false
WATCH_MODE=false
SHOW_HELP=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -n|--dry-run)   DRY_RUN=true;    shift ;;
        -w|--watch)     WATCH_MODE=true; shift ;;
        -h|--help)      SHOW_HELP=true;  shift ;;
        *) log_error "未知参数: $1"; exit 1 ;;
    esac
done

if $SHOW_HELP; then
    echo ""
    echo "用法: ./deploy.sh [选项]"
    echo ""
    echo "选项:"
    echo "  -n, --dry-run   模拟运行，只显示将要同步的文件，不实际传输"
    echo "  -w, --watch     监听模式，文件变化时自动触发同步（需要 fswatch）"
    echo "  -h, --help      显示帮助信息"
    echo ""
    echo "配置文件: deploy.conf（从 deploy.conf.example 复制并修改）"
    echo ""
    exit 0
fi

# ---- 构建 rsync 排除规则 ----
EXCLUDE_OPTS=""
DEFAULT_EXCLUDES=(
    ".git/"
    ".gitignore"
    "__pycache__/"
    "*.pyc"
    "*.pyo"
    ".env"
    "*.env"
    "venv/"
    ".venv/"
    "node_modules/"
    ".DS_Store"
    "*.log"
    "deploy.conf"
)

for item in "${DEFAULT_EXCLUDES[@]}"; do
    EXCLUDE_OPTS="$EXCLUDE_OPTS --exclude='$item'"
done

# 加载用户自定义排除项
if [ -n "$EXCLUDE_PATTERNS" ]; then
    IFS=',' read -ra CUSTOM_EXCLUDES <<< "$EXCLUDE_PATTERNS"
    for item in "${CUSTOM_EXCLUDES[@]}"; do
        item=$(echo "$item" | xargs)
        EXCLUDE_OPTS="$EXCLUDE_OPTS --exclude='$item'"
    done
fi

# ---- 构建 rsync 命令 ----
RSYNC_OPTS="-avz --progress"
if $DRY_RUN; then
    RSYNC_OPTS="$RSYNC_OPTS --dry-run"
fi

SSH_CMD="ssh -p $SSH_PORT $SSH_KEY_OPT -o StrictHostKeyChecking=no -o ConnectTimeout=10"

RSYNC_CMD="rsync $RSYNC_OPTS \
    -e \"$SSH_CMD\" \
    $EXCLUDE_OPTS \
    ${LOCAL_PATH%/}/ \
    ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PATH}/"

# ---- 执行同步 ----
do_sync() {
    local start_time=$(date +%s)

    log_info "开始同步..."
    log_info "本地路径: $LOCAL_PATH"
    log_info "远端目标: ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PATH}"
    if $DRY_RUN; then
        log_warn "【模拟模式】不会实际传输文件"
    fi
    echo ""

    eval $RSYNC_CMD
    local exit_code=$?

    local end_time=$(date +%s)
    local elapsed=$((end_time - start_time))

    echo ""
    if [ $exit_code -eq 0 ]; then
        log_success "同步完成！耗时 ${elapsed}s"
        log_success "远端路径: ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PATH}"

        # 同步后执行远端命令（可选）
        if [ -n "$POST_SYNC_CMD" ]; then
            log_info "执行远端命令: $POST_SYNC_CMD"
            ssh -p "$SSH_PORT" $SSH_KEY_OPT \
                -o StrictHostKeyChecking=no \
                "${REMOTE_USER}@${REMOTE_HOST}" \
                "cd ${REMOTE_PATH} && $POST_SYNC_CMD"
            log_success "远端命令执行完成"
        fi
    else
        log_error "同步失败，退出码: $exit_code"
        exit $exit_code
    fi
}

# ---- 监听模式 ----
do_watch() {
    if ! command -v fswatch &>/dev/null; then
        log_error "监听模式需要 fswatch，请先安装："
        log_error "  macOS:  brew install fswatch"
        log_error "  Linux:  apt-get install inotify-tools  或  yum install inotify-tools"
        exit 1
    fi

    log_info "进入监听模式，监听目录: $LOCAL_PATH"
    log_info "按 Ctrl+C 退出"
    echo ""

    # 先执行一次全量同步
    do_sync

    # 监听文件变化
    fswatch -o --exclude='.git' --exclude='__pycache__' \
        --exclude='*.pyc' --exclude='deploy.conf' \
        "$LOCAL_PATH" | while read -r event; do
        echo ""
        log_info "检测到文件变化，触发同步..."
        do_sync
    done
}

# ---- 主入口 ----
if $WATCH_MODE; then
    do_watch
else
    do_sync
fi
