#!/usr/bin/env bash
# ima_link.sh
# -----------
# 把 Obsidian vault 里的 IMA 同步目录软链到 trading-review-wiki 的 raw/sources/wechat-mp/
#
# 同时可选地把 IMA 的 attachments 软链到 raw/assets/wechat-mp/
#
# 用法:
#   ./ima_link.sh --vault ~/ObsidianVault/A股研究 --wiki ~/wiki
#   ./ima_link.sh --vault ~/ObsidianVault/A股研究 --wiki ~/wiki --ima-subdir IMA
#   ./ima_link.sh --check                            # 只检查已有链接状态
#   ./ima_link.sh --vault ... --wiki ... --dry-run
#   ./ima_link.sh --vault ... --wiki ... --normalize # 链好后顺便跑一次 normalize_ima.py

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

VAULT=""
WIKI=""
IMA_SUBDIR="IMA"          # Obsidian 内 IMA 同步插件的子目录名
WIKI_SUBDIR="wechat-mp"   # wiki/raw/sources/ 下的目标子目录名
DRY_RUN=0
CHECK_ONLY=0
NORMALIZE=0

usage() {
  sed -n '2,16p' "$0"
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --vault)      VAULT="$2"; shift 2 ;;
    --wiki)       WIKI="$2"; shift 2 ;;
    --ima-subdir) IMA_SUBDIR="$2"; shift 2 ;;
    --wiki-subdir) WIKI_SUBDIR="$2"; shift 2 ;;
    --dry-run)    DRY_RUN=1; shift ;;
    --check)      CHECK_ONLY=1; shift ;;
    --normalize)  NORMALIZE=1; shift ;;
    -h|--help)    usage ;;
    *) echo "unknown arg: $1" >&2; exit 1 ;;
  esac
done

log()  { printf '[%s] %s\n' "$(date '+%F %T')" "$*"; }
warn() { printf '[%s] WARN %s\n' "$(date '+%F %T')" "$*" >&2; }
die()  { printf '[%s] ERROR %s\n' "$(date '+%F %T')" "$*" >&2; exit 1; }

# 把 ~ 展开 + 转绝对路径
expand() {
  local p="$1"
  p="${p/#\~/$HOME}"
  # readlink -f 在 macOS 默认没有，用 cd+pwd 兜底
  if command -v greadlink >/dev/null 2>&1; then
    greadlink -f "$p"
  elif readlink -f "$p" >/dev/null 2>&1; then
    readlink -f "$p"
  else
    (cd "$(dirname "$p")" 2>/dev/null && printf '%s/%s\n' "$(pwd)" "$(basename "$p")") || printf '%s\n' "$p"
  fi
}

# ===== check mode =====
if (( CHECK_ONLY == 1 )); then
  if [[ -z "$WIKI" ]]; then
    die "--check 需要 --wiki <path>"
  fi
  wiki_abs="$(expand "$WIKI")"
  target="$wiki_abs/raw/sources/$WIKI_SUBDIR"
  log "检查: $target"
  if [[ -L "$target" ]]; then
    log "  类型: symlink"
    log "  指向: $(readlink "$target")"
    if [[ -d "$target" ]]; then
      log "  状态: OK (目标可达)"
      count=$(find -L "$target" -maxdepth 1 -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
      log "  .md 数: $count"
    else
      warn "  状态: BROKEN (目标不可达)"
      exit 2
    fi
  elif [[ -d "$target" ]]; then
    warn "  类型: 普通目录（不是 symlink）"
    warn "  说明: 你可能手动拷贝过 / 或之前装过其它同步工具"
    exit 3
  else
    warn "  状态: 不存在"
    exit 4
  fi
  exit 0
fi

# ===== link mode =====
[[ -n "$VAULT" ]] || die "缺少 --vault <Obsidian vault path>"
[[ -n "$WIKI" ]] || die "缺少 --wiki <trading-review-wiki 项目目录>"

vault_abs="$(expand "$VAULT")"
wiki_abs="$(expand "$WIKI")"

[[ -d "$vault_abs" ]] || die "vault 目录不存在: $vault_abs"
[[ -d "$wiki_abs" ]] || die "wiki 目录不存在: $wiki_abs (是不是没初始化？跑 scripts/wiki/setup_wiki.sh 先)"

src="$vault_abs/$IMA_SUBDIR"
src_assets="$vault_abs/$IMA_SUBDIR/attachments"

if [[ ! -d "$src" ]]; then
  warn "$src 不存在"
  warn "  → 检查 Obsidian 里 ima.copilot Sync 插件的同步目录是不是 $IMA_SUBDIR"
  warn "  → 或者用 --ima-subdir 改成实际值"
  exit 1
fi

raw_sources="$wiki_abs/raw/sources"
raw_assets="$wiki_abs/raw/assets"
mkdir -p "$raw_sources" "$raw_assets"

dst="$raw_sources/$WIKI_SUBDIR"
dst_assets="$raw_assets/$WIKI_SUBDIR"

link_one() {
  local s="$1" d="$2" label="$3"
  if [[ -L "$d" ]]; then
    cur="$(readlink "$d")"
    if [[ "$cur" == "$s" ]]; then
      log "$label: 已存在且指向正确 ($d → $s)"
      return 0
    fi
    warn "$label: 已存在但指向 $cur，覆盖为 $s"
    (( DRY_RUN == 1 )) || rm "$d"
  elif [[ -e "$d" ]]; then
    die "$label 路径 $d 存在且不是 symlink，拒绝覆盖（手动检查）"
  fi
  if (( DRY_RUN == 1 )); then
    log "$label: (dry-run) ln -s $s $d"
  else
    ln -s "$s" "$d"
    log "$label: ln -s $s $d"
  fi
}

log "==== ima_link 开始 ===="
log "vault:       $vault_abs"
log "wiki:        $wiki_abs"
log "源:          $src"
log "目标:        $dst"

link_one "$src" "$dst" "正文链接"

if [[ -d "$src_assets" ]]; then
  link_one "$src_assets" "$dst_assets" "附件链接"
else
  log "附件目录 $src_assets 不存在，跳过附件软链（IMA 还没存过含图片的文章）"
fi

if (( NORMALIZE == 1 && DRY_RUN == 0 )); then
  log "==== 跑 normalize_ima.py ===="
  python3 "$SCRIPT_DIR/normalize_ima.py" "$src" --quiet
fi

log "==== 完成 ===="
log "下一步: 打开 trading-review-wiki, 选 $wiki_abs 作为项目, 等待 LLM 摄入"
