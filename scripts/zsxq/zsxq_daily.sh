#!/usr/bin/env bash
# =============================================================
# zsxq_daily.sh
# -------------------------------------------------------------
# 增量同步知识星球内容 → 软链到 trading-review-wiki/raw/sources/zsxq/
#
# 用法:
#   ./zsxq_daily.sh                       # 增量同步 + 软链
#   ./zsxq_daily.sh --full                # 全量同步
#   ./zsxq_daily.sh --no-link             # 只抓不软链
#   ./zsxq_daily.sh --rsync-to <ssh-dest> # 抓完 rsync 到远端
#   ./zsxq_daily.sh --dry-run             # 不实际执行
#   ./zsxq_daily.sh --help
#
# 依赖:
#   - uv (https://astral.sh/uv)
#   - ZsxqCrawler clone 到 $ZSXQ_DIR（默认 ~/ZsxqCrawler）
#   - 同目录的 config.toml（从 config.toml.example 拷过来填好）
# =============================================================

set -euo pipefail

# ---------- 配置项 ----------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.toml"
ZSXQ_DIR="${ZSXQ_DIR:-${HOME}/ZsxqCrawler}"
LOG_FILE="${LOG_FILE:-/tmp/zsxq-daily.log}"

# ---------- 默认参数 ----------
MODE="incremental"   # incremental | full
DO_LINK=true
RSYNC_DEST=""
DRY_RUN=false

# ---------- 颜色（仅 tty）----------
if [[ -t 1 ]]; then
  C_RESET="\033[0m"; C_RED="\033[31m"; C_GREEN="\033[32m"
  C_YELLOW="\033[33m"; C_BLUE="\033[34m"; C_DIM="\033[2m"
else
  C_RESET=""; C_RED=""; C_GREEN=""; C_YELLOW=""; C_BLUE=""; C_DIM=""
fi

log() {
  local level="$1"; shift
  local color="$C_RESET"
  case "$level" in
    INFO)  color="$C_BLUE"  ;;
    OK)    color="$C_GREEN" ;;
    WARN)  color="$C_YELLOW";;
    ERROR) color="$C_RED"   ;;
  esac
  printf "${color}[%s] %s${C_RESET}\n" "$level" "$*" | tee -a "$LOG_FILE"
}

usage() {
  sed -n '2,18p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  exit 0
}

# ---------- 解析参数 ----------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --full)       MODE="full"; shift ;;
    --no-link)    DO_LINK=false; shift ;;
    --rsync-to)   RSYNC_DEST="$2"; shift 2 ;;
    --dry-run)    DRY_RUN=true; shift ;;
    -h|--help)    usage ;;
    *)            log ERROR "未知参数: $1"; usage ;;
  esac
done

# ---------- 前置检查 ----------
[[ -f "$CONFIG_FILE" ]] || {
  log ERROR "缺少 $CONFIG_FILE"
  log INFO  "拷贝 config.toml.example 后填入真实值"
  exit 1
}

[[ -d "$ZSXQ_DIR" ]] || {
  log ERROR "ZsxqCrawler 目录不存在: $ZSXQ_DIR"
  log INFO  "git clone https://github.com/2dot4/ZsxqCrawler.git $ZSXQ_DIR"
  exit 1
}

command -v uv >/dev/null || {
  log ERROR "缺少 uv，安装: curl -LsSf https://astral.sh/uv/install.sh | sh"
  exit 1
}

# ---------- 解析配置（最小化 TOML 读取，不引入额外依赖）----------
# 简单 grep，仅读我们用到的几个 key
parse_toml() {
  local key="$1"
  grep -E "^\s*${key}\s*=" "$CONFIG_FILE" | head -1 | sed -E 's/^[^=]*=\s*"?([^"]*)"?.*/\1/' | sed 's/[[:space:]]*$//'
}

ARTICLES_DIR="$(parse_toml articles_dir)"
WIKI_TARGET="$(parse_toml wiki_link_target)"
LINK_MODE="$(parse_toml link_mode)"
ATTACHMENTS_DIR="$(parse_toml attachments_dir)"

# 展开 ~
ARTICLES_DIR="${ARTICLES_DIR/#\~/$HOME}"
WIKI_TARGET="${WIKI_TARGET/#\~/$HOME}"
ATTACHMENTS_DIR="${ATTACHMENTS_DIR/#\~/$HOME}"

log INFO "ZsxqCrawler 路径: $ZSXQ_DIR"
log INFO "输出文章目录:    $ARTICLES_DIR"
log INFO "Wiki 软链目标:   $WIKI_TARGET"
log INFO "运行模式:        $MODE"
log INFO "是否软链:        $DO_LINK"
[[ -n "$RSYNC_DEST" ]] && log INFO "rsync 目标:      $RSYNC_DEST"
$DRY_RUN && log WARN "DRY-RUN 模式，不会实际执行命令"

# ---------- Step 1: 跑 ZsxqCrawler ----------
run_crawler() {
  log INFO "----- Step 1/3: 同步内容 -----"

  pushd "$ZSXQ_DIR" >/dev/null

  # 读 groups 数组（粗暴解析）
  local groups
  groups=$(grep -E '^\s*group_id\s*=' "$CONFIG_FILE" | sed -E 's/^[^=]*=\s*"?([^"]*)"?.*/\1/')

  if [[ -z "$groups" ]]; then
    log ERROR "config.toml 中未配置任何 [[groups]]"
    exit 1
  fi

  local flag
  [[ "$MODE" == "full" ]] && flag="--full" || flag="--incremental"

  for gid in $groups; do
    log INFO "→ group_id=$gid ($flag)"
    if $DRY_RUN; then
      echo "[DRY] uv run zsxq-md crawl --group-id $gid $flag"
    else
      uv run zsxq-md crawl --group-id "$gid" "$flag" 2>&1 | tee -a "$LOG_FILE" || {
        log ERROR "group $gid 同步失败，继续下一个"
        continue
      }
    fi
  done

  popd >/dev/null
  log OK "Step 1 完成"
}

# ---------- Step 2: 软链到 wiki ----------
link_to_wiki() {
  if ! $DO_LINK; then
    log INFO "跳过软链（--no-link）"
    return
  fi

  log INFO "----- Step 2/3: 软链到 wiki -----"

  if [[ ! -d "$ARTICLES_DIR" ]]; then
    log WARN "$ARTICLES_DIR 不存在，跳过软链"
    return
  fi

  if $DRY_RUN; then
    echo "[DRY] mkdir -p $WIKI_TARGET"
    echo "[DRY] $LINK_MODE: $ARTICLES_DIR/* → $WIKI_TARGET/"
  else
    mkdir -p "$WIKI_TARGET"
    if [[ "$LINK_MODE" == "symlink" ]]; then
      # 软链整个 articles 目录到 wiki/sources/zsxq/articles
      # 一个目录链接更好维护（rm 一个就清空）
      local link_path="$WIKI_TARGET/articles"
      if [[ -L "$link_path" || -e "$link_path" ]]; then
        rm -rf "$link_path"
      fi
      ln -s "$ARTICLES_DIR" "$link_path"
      log OK "符号链接: $link_path → $ARTICLES_DIR"
    else
      rsync -a --delete "$ARTICLES_DIR/" "$WIKI_TARGET/articles/"
      log OK "复制完成: $WIKI_TARGET/articles/"
    fi

    # 附件同样处理
    if [[ -d "$ATTACHMENTS_DIR" ]]; then
      local att_link="$WIKI_TARGET/attachments"
      if [[ "$LINK_MODE" == "symlink" ]]; then
        [[ -L "$att_link" || -e "$att_link" ]] && rm -rf "$att_link"
        ln -s "$ATTACHMENTS_DIR" "$att_link"
      else
        rsync -a --delete "$ATTACHMENTS_DIR/" "$att_link/"
      fi
    fi
  fi

  log OK "Step 2 完成"
}

# ---------- Step 3: rsync 到远端（可选）----------
rsync_to_remote() {
  if [[ -z "$RSYNC_DEST" ]]; then
    return
  fi

  log INFO "----- Step 3/3: rsync 到 $RSYNC_DEST -----"

  if $DRY_RUN; then
    echo "[DRY] rsync -avz --delete $WIKI_TARGET/ $RSYNC_DEST/"
  else
    rsync -avz --delete "$WIKI_TARGET/" "$RSYNC_DEST/" 2>&1 | tee -a "$LOG_FILE"
  fi

  log OK "Step 3 完成"
}

# ---------- 主流程 ----------
START_TS=$(date +%s)
log INFO "======================================"
log INFO "zsxq_daily.sh 启动 @ $(date '+%F %T')"
log INFO "======================================"

run_crawler
link_to_wiki
rsync_to_remote

END_TS=$(date +%s)
ELAPSED=$((END_TS - START_TS))
log OK "全部完成，耗时 ${ELAPSED}s"
log INFO "======================================"
