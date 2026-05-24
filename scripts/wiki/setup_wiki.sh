#!/usr/bin/env bash
# setup_wiki.sh
# -------------
# 初始化一个新的 trading-review-wiki 工作区，并把 toolkit 的 4 个数据源链好。
#
# 用法:
#   ./setup_wiki.sh ~/wiki                              # 最小：建结构 + 放模板
#
#   ./setup_wiki.sh ~/wiki \                            # 完整：连 4 个数据源都链上
#     --ima-vault ~/ObsidianVault/A股研究 \
#     --zsxq-dir  ~/zsxq-data \
#     --wechat-dir ~/wechat-data/cleaned \
#     --research-dir ~/research-pdfs
#
#   ./setup_wiki.sh ~/wiki --dry-run                    # 看会建什么但不动手
#   ./setup_wiki.sh ~/wiki --force-templates            # 覆盖已有的 purpose.md / schema.md

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLKIT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

WIKI=""
IMA_VAULT=""
ZSXQ_DIR=""
WECHAT_DIR=""
RESEARCH_DIR=""
WEBCLIP_DIR=""
DRY_RUN=0
FORCE_TEMPLATES=0

usage() {
  sed -n '2,16p' "$0"
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ima-vault)      IMA_VAULT="$2"; shift 2 ;;
    --zsxq-dir)       ZSXQ_DIR="$2"; shift 2 ;;
    --wechat-dir)     WECHAT_DIR="$2"; shift 2 ;;
    --research-dir)   RESEARCH_DIR="$2"; shift 2 ;;
    --webclip-dir)    WEBCLIP_DIR="$2"; shift 2 ;;
    --dry-run)        DRY_RUN=1; shift ;;
    --force-templates) FORCE_TEMPLATES=1; shift ;;
    -h|--help)        usage ;;
    -*) echo "unknown flag: $1" >&2; exit 1 ;;
    *) WIKI="$1"; shift ;;
  esac
done

[[ -n "$WIKI" ]] || { echo "用法: $0 <wiki-dir> [options]" >&2; exit 1; }

# 展开 ~
WIKI="${WIKI/#\~/$HOME}"

log()  { printf '[%s] %s\n' "$(date '+%F %T')" "$*"; }
warn() { printf '[%s] WARN %s\n' "$(date '+%F %T')" "$*" >&2; }
die()  { printf '[%s] ERROR %s\n' "$(date '+%F %T')" "$*" >&2; exit 1; }

run() {
  if (( DRY_RUN == 1 )); then
    printf '[dry-run] %s\n' "$*"
  else
    "$@"
  fi
}

write_file() {
  local dst="$1" content="$2" force="${3:-0}"
  if [[ -f "$dst" && "$force" != "1" ]]; then
    log "保留: $dst (已存在)"
    return 0
  fi
  if (( DRY_RUN == 1 )); then
    printf '[dry-run] write %s (%d bytes)\n' "$dst" "${#content}"
  else
    mkdir -p "$(dirname "$dst")"
    printf '%s' "$content" > "$dst"
    log "写入: $dst"
  fi
}

link_source() {
  local src_raw="$1" rel_target="$2" label="$3"
  [[ -n "$src_raw" ]] || return 0
  local src="${src_raw/#\~/$HOME}"
  if [[ ! -e "$src" ]]; then
    warn "$label 源 $src 不存在，跳过"
    return 0
  fi
  local dst="$WIKI/raw/sources/$rel_target"
  if [[ -L "$dst" ]]; then
    local cur
    cur="$(readlink "$dst")"
    if [[ "$cur" == "$src" ]]; then
      log "$label: 已存在且指向正确"
      return 0
    fi
    log "$label: 替换软链 ($cur → $src)"
    run rm "$dst"
  elif [[ -e "$dst" ]]; then
    warn "$label: $dst 存在且不是 symlink，跳过（请手动处理）"
    return 0
  fi
  run mkdir -p "$(dirname "$dst")"
  run ln -s "$src" "$dst"
  log "$label: ln -s $src $dst"
}

# ===== 0. 检查 toolkit 模板存在 =====
[[ -f "$TOOLKIT_ROOT/templates/purpose.md" ]] || die "找不到 templates/purpose.md (TOOLKIT_ROOT=$TOOLKIT_ROOT)"
[[ -f "$TOOLKIT_ROOT/templates/schema.md" ]] || die "找不到 templates/schema.md"

log "==== setup_wiki 开始 ===="
log "WIKI:          $WIKI"
log "TOOLKIT:       $TOOLKIT_ROOT"
log "force tpl:     $FORCE_TEMPLATES   dry-run: $DRY_RUN"

# ===== 1. 建目录骨架 =====
log "---- 1. 建目录骨架 ----"
for d in \
  "" \
  "raw" "raw/sources" "raw/assets" "raw/日复盘" \
  "wiki" "wiki/股票" "wiki/题材" "wiki/板块" "wiki/模式" \
  "wiki/错误" "wiki/人物" "wiki/事件" "wiki/综合" \
  "wiki/资料" "wiki/queries" \
  ".llm-wiki" ".llm-wiki/chats"
do
  run mkdir -p "$WIKI/$d"
done

# ===== 2. 放 purpose.md / schema.md =====
log "---- 2. 放 purpose.md / schema.md ----"
if (( FORCE_TEMPLATES == 1 )); then
  run cp "$TOOLKIT_ROOT/templates/purpose.md" "$WIKI/purpose.md"
  run cp "$TOOLKIT_ROOT/templates/schema.md" "$WIKI/schema.md"
  log "强制覆盖: purpose.md, schema.md"
else
  if [[ ! -f "$WIKI/purpose.md" ]]; then
    run cp "$TOOLKIT_ROOT/templates/purpose.md" "$WIKI/purpose.md"
    log "写入: $WIKI/purpose.md"
  else
    log "保留: $WIKI/purpose.md (已存在)"
  fi
  if [[ ! -f "$WIKI/schema.md" ]]; then
    run cp "$TOOLKIT_ROOT/templates/schema.md" "$WIKI/schema.md"
    log "写入: $WIKI/schema.md"
  else
    log "保留: $WIKI/schema.md (已存在)"
  fi
fi

# ===== 3. 建 index.md / log.md / overview.md 骨架 =====
log "---- 3. 建 index.md / log.md / overview.md 骨架 ----"

INDEX_CONTENT="---
type: index
title: Wiki 目录
auto_updated: false
---

# Wiki 目录

> 这个文件随着摄入自动更新；你也可以手动 pin 重要页面到顶部。

## 股票

（首次摄入后会自动填充）

## 题材

## 板块

## 模式

## 错误

## 人物

## 事件

## 综合

## 资料

"

LOG_CONTENT="---
type: log
title: 操作日志
---

# 操作日志

> 一行一条，可解析格式：YYYY-MM-DD HH:MM | action | summary

$(date '+%Y-%m-%d %H:%M') | init | wiki 初始化（由 trading-research-toolkit setup_wiki.sh 创建）
"

OVERVIEW_CONTENT="---
type: overview
title: 全局概要
auto_updated: true
last_updated: $(date '+%Y-%m-%d')
---

# 全局概要

> 这个文件每次摄入后被 trading-review-wiki 重新生成。请不要手动编辑。

(尚无内容 — 摄入第一篇资料后会自动生成)
"

write_file "$WIKI/wiki/index.md" "$INDEX_CONTENT"
write_file "$WIKI/wiki/log.md" "$LOG_CONTENT"
write_file "$WIKI/wiki/overview.md" "$OVERVIEW_CONTENT"

# ===== 4. 软链上游数据源 =====
log "---- 4. 软链上游数据源 ----"
link_source "$IMA_VAULT/IMA" "wechat-mp" "公众号 (IMA)"
[[ -d "${IMA_VAULT/#\~/$HOME}/IMA/attachments" ]] && \
  link_source "$IMA_VAULT/IMA/attachments" "../assets/wechat-mp" "公众号附件"
link_source "$ZSXQ_DIR" "zsxq" "知识星球"
link_source "$WECHAT_DIR" "wechat" "微信群（清洗后）"
link_source "$RESEARCH_DIR" "research" "研报 PDF"
link_source "$WEBCLIP_DIR" "webclip" "网页剪藏"

# ===== 5. 提供 Obsidian 兼容配置（可选） =====
log "---- 5. 写 Obsidian 兼容配置 ----"
OBSIDIAN_DIR="$WIKI/.obsidian"
APP_CONTENT='{
  "promptDelete": false,
  "alwaysUpdateLinks": true,
  "newLinkFormat": "shortest",
  "useMarkdownLinks": false
}'
write_file "$OBSIDIAN_DIR/app.json" "$APP_CONTENT"

# ===== 6. 提示下一步 =====
log "==== 完成 ===="
cat <<EOF

✅ wiki 已初始化在: $WIKI

下一步:

1. 打开 trading-review-wiki 桌面应用
2. 创建 / 打开项目 → 选择目录 $WIKI
3. 设置 → 配置 LLM provider（建议先选 Custom + DeepSeek，详见 docs/llm-provider-routing.md）
4. 摄入测试: 把一篇短的 .md 拖到 raw/sources/ 里，看活动面板自动启动摄入

如果 4 个数据源都链了:
  $WIKI/raw/sources/
  $(ls -1 "$WIKI/raw/sources/" 2>/dev/null | sed 's|^|    - |' || echo "    (尚无)")

EOF
