#!/usr/bin/env bash
# wechat_daily.sh
# ---------------
# 微信群每日抓取 + 清洗 + 软链入 wiki 主流程
#
# 流程:
#   1. 调用 wechat-digest/extract-messages.py，按配置的群名抓取昨天的聊天
#   2. 对每个群跑 wechat_clean.py，输出到 OUTPUT_DIR/{群名}/{date}.md
#   3. 把整个 OUTPUT_DIR/{群名}/ 软链到 WIKI_RAW_DIR/wechat/{群名}
#   4. macOS 下发通知，Linux 下写日志
#
# 用法:
#   ./wechat_daily.sh                       # 抓昨天
#   ./wechat_daily.sh 2026-05-24            # 抓指定日期
#   ./wechat_daily.sh --dry-run             # 不写文件
#   ./wechat_daily.sh --skip-extract        # 跳过抓取，只清洗已有文件（调试用）
#   ./wechat_daily.sh --no-link             # 不创建软链
#
# 配置: 同目录下 wechat.env（参考 wechat.env.example）

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${WECHAT_ENV:-$SCRIPT_DIR/wechat.env}"

# ===== 默认配置 =====
WECHAT_DIGEST_DIR="${WECHAT_DIGEST_DIR:-$HOME/wechat-digest}"
OUTPUT_DIR="${OUTPUT_DIR:-$HOME/wechat-data/cleaned}"
WIKI_RAW_DIR="${WIKI_RAW_DIR:-$HOME/wiki/raw/sources}"
GROUPS=()                            # 群名列表，默认空（由 env 文件提供）
ALIASES_FILE="${ALIASES_FILE:-$SCRIPT_DIR/aliases.json}"
ANONYMIZE="${ANONYMIZE:-0}"          # 1 = 启用脱敏
HOUR_OFFSET="${HOUR_OFFSET:-0}"      # 给 extract-messages.py 用，0 = 全天
PYTHON="${PYTHON:-python3}"
NOTIFY="${NOTIFY:-auto}"             # auto / on / off

# ===== 加载用户 env =====
if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
fi

# ===== 参数解析 =====
DATE=""
DRY_RUN=0
SKIP_EXTRACT=0
NO_LINK=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)        DRY_RUN=1; shift ;;
    --skip-extract)   SKIP_EXTRACT=1; shift ;;
    --no-link)        NO_LINK=1; shift ;;
    -h|--help)
      sed -n '2,20p' "$0"; exit 0 ;;
    *)
      DATE="$1"; shift ;;
  esac
done

if [[ -z "$DATE" ]]; then
  # 跨平台拿昨天日期
  if date -v-1d +%Y-%m-%d >/dev/null 2>&1; then
    DATE=$(date -v-1d +%Y-%m-%d)            # macOS BSD date
  else
    DATE=$(date -d "yesterday" +%Y-%m-%d)   # Linux GNU date
  fi
fi

if (( ${#GROUPS[@]} == 0 )); then
  echo "ERROR: 没有配置群名。请编辑 $ENV_FILE 并设置 GROUPS=(\"群A\" \"群B\")" >&2
  exit 1
fi

EXTRACT_SCRIPT="$WECHAT_DIGEST_DIR/extract-messages.py"
RAW_DIR="$WECHAT_DIGEST_DIR/output"
CLEAN_SCRIPT="$SCRIPT_DIR/wechat_clean.py"

# ===== 日志 =====
log() { printf '[%s] %s\n' "$(date '+%F %T')" "$*"; }
warn() { printf '[%s] WARN %s\n' "$(date '+%F %T')" "$*" >&2; }
die() { printf '[%s] ERROR %s\n' "$(date '+%F %T')" "$*" >&2; exit 1; }

notify_user() {
  local title="$1" body="$2"
  case "$NOTIFY" in
    off) return ;;
    on|auto) ;;
    *) return ;;
  esac
  if command -v osascript >/dev/null 2>&1; then
    osascript -e "display notification \"$body\" with title \"$title\"" || true
  elif command -v notify-send >/dev/null 2>&1; then
    notify-send "$title" "$body" || true
  fi
}

# ===== 预检 =====
[[ -d "$WECHAT_DIGEST_DIR" ]] || die "WECHAT_DIGEST_DIR 不存在: $WECHAT_DIGEST_DIR"
[[ -x "$CLEAN_SCRIPT" || -f "$CLEAN_SCRIPT" ]] || die "找不到清洗脚本: $CLEAN_SCRIPT"
if (( SKIP_EXTRACT == 0 )); then
  [[ -f "$EXTRACT_SCRIPT" ]] || die "找不到 extract-messages.py: $EXTRACT_SCRIPT"
fi

mkdir -p "$OUTPUT_DIR"

log "==== wechat-daily 开始 ===="
log "日期:        $DATE"
log "群:          ${GROUPS[*]}"
log "输出:        $OUTPUT_DIR"
log "wiki 链接到: $WIKI_RAW_DIR/wechat/  (--no-link=$NO_LINK)"
log "脱敏:        $ANONYMIZE   dry-run=$DRY_RUN  skip-extract=$SKIP_EXTRACT"

ok_count=0
fail_count=0
skip_count=0

for group in "${GROUPS[@]}"; do
  log "---- 处理群: $group ----"
  raw_file="$RAW_DIR/${DATE}-${group}-聊天记录.md"

  # 1. 抓取
  if (( SKIP_EXTRACT == 0 )); then
    log "抓取: $EXTRACT_SCRIPT \"$group\" $DATE --hour-offset $HOUR_OFFSET"
    if (( DRY_RUN == 1 )); then
      log "  (dry-run, 跳过实际抓取)"
    else
      ( cd "$WECHAT_DIGEST_DIR" && \
        $PYTHON extract-messages.py "$group" "$DATE" --hour-offset "$HOUR_OFFSET" ) \
        || { warn "抓取失败: $group"; ((fail_count++)); continue; }
    fi
  fi

  # 2. 检查抓取结果
  if [[ ! -f "$raw_file" ]]; then
    warn "原始文件不存在（可能这天群里没消息）: $raw_file"
    ((skip_count++))
    continue
  fi

  # 3. 清洗
  group_out_dir="$OUTPUT_DIR/$group"
  mkdir -p "$group_out_dir"
  out_file="$group_out_dir/${DATE}.md"

  clean_args=(
    "$raw_file"
    -o "$out_file"
    --group "$group"
    --date "$DATE"
  )
  [[ "$ANONYMIZE" == "1" ]] && clean_args+=(--anonymize)
  [[ -f "$ALIASES_FILE" ]] && clean_args+=(--aliases "$ALIASES_FILE")
  (( DRY_RUN == 1 )) && clean_args+=(--dry-run)

  log "清洗: wechat_clean.py ${clean_args[*]}"
  if $PYTHON "$CLEAN_SCRIPT" "${clean_args[@]}"; then
    ((ok_count++))
  else
    warn "清洗失败: $group"
    ((fail_count++))
    continue
  fi
done

# 4. 软链到 wiki
if (( NO_LINK == 0 && DRY_RUN == 0 )); then
  link_target="$WIKI_RAW_DIR/wechat"
  if [[ -d "$WIKI_RAW_DIR" ]]; then
    mkdir -p "$link_target"
    for group in "${GROUPS[@]}"; do
      src="$OUTPUT_DIR/$group"
      dst="$link_target/$group"
      [[ -d "$src" ]] || continue
      if [[ -L "$dst" || -e "$dst" ]]; then
        # 已存在，跳过（不覆盖用户可能的手动配置）
        continue
      fi
      ln -s "$src" "$dst"
      log "软链: $dst -> $src"
    done
  else
    warn "WIKI_RAW_DIR 不存在: $WIKI_RAW_DIR (跳过软链)"
  fi
fi

log "==== 完成 ====   成功=$ok_count  失败=$fail_count  跳过=$skip_count"

if (( ok_count > 0 )); then
  notify_user "wechat-daily" "$DATE 完成: $ok_count 个群已入库"
fi

# 让定时任务看到 1 = 有失败
(( fail_count > 0 )) && exit 1 || exit 0
