#!/usr/bin/env python3
"""
normalize_ima.py
================

把 IMA Obsidian sync 插件落下的 markdown 文件 frontmatter 规范化成
trading-review-wiki / templates/schema.md 期望的 `raw_source` 形态。

行为
----
1. 读取目录里所有 `.md`（递归）
2. 解析 YAML frontmatter（容忍缺失 / 字段名变体）
3. 重写成统一 schema:

   ---
   type: raw_source
   source_type: wechat-mp
   title: ...
   source: ...                 # 公众号名
   url: ...                    # 原文链接（去 tracking 参数）
   clipped_at: YYYY-MM-DD
   tags: [...]                 # 保留 IMA 的标签
   ima_doc_id: ...             # 可追溯
   normalized: true            # 幂等标记
   ---

4. 已经 normalized: true 的文件跳过
5. 正文不动（保留 IMA 同步的图片、表格、公式）

零依赖：只用 Python 3 标准库。

用法
----
   ./normalize_ima.py PATH              # 就地改写
   ./normalize_ima.py PATH --dry-run    # 只报告，不写
   ./normalize_ima.py PATH --force      # 强制重新 normalize（覆盖 normalized: true）
"""

from __future__ import annotations

import argparse
import re
import sys
from datetime import datetime, timezone, timedelta
from pathlib import Path
from urllib.parse import urlparse, urlunparse, parse_qsl, urlencode

CST = timezone(timedelta(hours=8))

# =============================================================
# Frontmatter 解析（零依赖 YAML 子集 parser）
# =============================================================

FRONTMATTER_RE = re.compile(
    r"^---\s*\n(.*?)\n---\s*\n",
    re.DOTALL,
)


def parse_frontmatter(text: str) -> tuple[dict[str, object], str]:
    """返回 (fields, body)。如果没有 frontmatter，fields={}, body=text。"""
    m = FRONTMATTER_RE.match(text)
    if not m:
        return {}, text
    raw_yaml = m.group(1)
    body = text[m.end():]
    fields = _parse_simple_yaml(raw_yaml)
    return fields, body


def _parse_simple_yaml(text: str) -> dict[str, object]:
    """
    支持子集：
      key: value
      key: "value"
      key: [a, b, c]
      key:
        - item1
        - item2
    多行 / 嵌套对象不支持（IMA 不会用）
    """
    result: dict[str, object] = {}
    lines = text.split("\n")
    i = 0
    while i < len(lines):
        line = lines[i].rstrip()
        if not line.strip() or line.lstrip().startswith("#"):
            i += 1
            continue
        m = re.match(r"^([\w_-]+)\s*:\s*(.*)$", line)
        if not m:
            i += 1
            continue
        key, raw = m.group(1), m.group(2).strip()
        if raw == "":
            # 看下面是不是 list of - items
            items: list[str] = []
            j = i + 1
            while j < len(lines):
                ll = lines[j]
                if re.match(r"^\s+-\s+", ll):
                    items.append(re.sub(r"^\s+-\s+", "", ll).strip().strip('"\''))
                    j += 1
                elif ll.strip() == "":
                    j += 1
                else:
                    break
            if items:
                result[key] = items
                i = j
                continue
            result[key] = ""
            i += 1
            continue
        # 内联 list: [a, b, c]
        if raw.startswith("[") and raw.endswith("]"):
            inner = raw[1:-1].strip()
            if not inner:
                result[key] = []
            else:
                result[key] = [
                    s.strip().strip('"\'')
                    for s in inner.split(",")
                ]
            i += 1
            continue
        # 引号包裹
        if (raw.startswith('"') and raw.endswith('"')) or \
           (raw.startswith("'") and raw.endswith("'")):
            raw = raw[1:-1]
        # boolean
        if raw.lower() == "true":
            result[key] = True
        elif raw.lower() == "false":
            result[key] = False
        else:
            result[key] = raw
        i += 1
    return result


def render_frontmatter(fields: dict[str, object]) -> str:
    """渲染回 YAML（同样子集）。key 顺序：固定 + 其余按字母序。"""
    fixed_order = [
        "type", "source_type", "title", "source", "author",
        "url", "clipped_at", "date", "tags",
        "ima_doc_id", "ima_kb", "normalized",
    ]
    seen = set()
    lines = ["---"]
    for k in fixed_order:
        if k in fields:
            lines.append(_render_kv(k, fields[k]))
            seen.add(k)
    for k in sorted(fields.keys()):
        if k in seen:
            continue
        lines.append(_render_kv(k, fields[k]))
    lines.append("---")
    return "\n".join(lines) + "\n"


def _render_kv(k: str, v: object) -> str:
    if isinstance(v, bool):
        return f"{k}: {'true' if v else 'false'}"
    if isinstance(v, list):
        inner = ", ".join(_quote_if_needed(str(x)) for x in v)
        return f"{k}: [{inner}]"
    s = str(v)
    return f"{k}: {_quote_if_needed(s)}"


def _quote_if_needed(s: str) -> str:
    if s == "":
        return '""'
    if any(c in s for c in [":", "#", "[", "]", "{", "}", ","]) or \
       s.strip() != s:
        return '"' + s.replace('"', r'\"') + '"'
    return s


# =============================================================
# URL 清洗
# =============================================================

# 微信公众号 URL 上常带的 tracking / share 参数
URL_DROP_PARAMS = {
    "chksm", "mid", "idx", "sn", "scene", "subscene", "sessionid",
    "clicktime", "enterid", "ascene", "devicetype", "version",
    "nettype", "abtest_cookie", "lang", "exportkey", "pass_ticket",
    "wx_header", "key", "uin", "biz",
}


def clean_url(url: str) -> str:
    """去掉公众号 tracking 参数，保留稳定的 __biz + 文章 hash。"""
    if not url:
        return url
    try:
        p = urlparse(url)
    except Exception:
        return url
    qs = parse_qsl(p.query, keep_blank_values=False)
    # 公众号链接的 __biz 是文章唯一标识的一部分，要留；其它 tracking 都去掉
    cleaned = [(k, v) for k, v in qs if k == "__biz" or k.lower() not in URL_DROP_PARAMS]
    new_query = urlencode(cleaned)
    return urlunparse(p._replace(query=new_query, fragment=""))


# =============================================================
# 字段映射（IMA 多版本字段名兼容）
# =============================================================

# (preferred_key, [variant aliases in priority order])
FIELD_ALIASES = {
    "title":      ["title", "name", "Title"],
    "source":     ["source", "author", "publisher", "公众号", "from"],
    "url":        ["url", "link", "原文链接", "source_url"],
    "clipped_at": ["clipped_at", "clipped", "created_at", "date", "时间"],
    "tags":       ["tags", "tag", "标签"],
    "ima_doc_id": ["ima_doc_id", "doc_id", "id"],
    "ima_kb":     ["ima_kb", "knowledge_base", "kb"],
}


def pick(fields: dict[str, object], aliases: list[str]) -> object | None:
    for k in aliases:
        if k in fields and fields[k] not in (None, "", []):
            return fields[k]
    return None


def normalize_fields(orig: dict[str, object]) -> dict[str, object]:
    out: dict[str, object] = {
        "type": "raw_source",
        "source_type": "wechat-mp",
    }
    for canonical, aliases in FIELD_ALIASES.items():
        val = pick(orig, aliases)
        if val is None:
            continue
        if canonical == "url":
            out["url"] = clean_url(str(val))
        elif canonical == "clipped_at":
            out["clipped_at"] = _normalize_date(str(val))
        elif canonical == "tags":
            if isinstance(val, list):
                out["tags"] = [str(x) for x in val]
            else:
                out["tags"] = [str(val)]
        else:
            out[canonical] = str(val).strip()

    # title 兜底：用文件名 stem
    if "title" not in out:
        out["title"] = "(待补充)"

    # clipped_at 兜底：用今天
    if "clipped_at" not in out:
        out["clipped_at"] = datetime.now(CST).strftime("%Y-%m-%d")

    out["normalized"] = True
    return out


def _normalize_date(s: str) -> str:
    s = s.strip()
    # ISO 8601 with timezone
    for fmt in (
        "%Y-%m-%dT%H:%M:%S%z",
        "%Y-%m-%dT%H:%M:%S.%f%z",
        "%Y-%m-%dT%H:%M:%S",
        "%Y-%m-%d %H:%M:%S",
        "%Y-%m-%d",
        "%Y/%m/%d",
    ):
        try:
            dt = datetime.strptime(s.replace("Z", "+0000"), fmt)
            return dt.strftime("%Y-%m-%d")
        except ValueError:
            continue
    # 最后兜底：原样返回
    return s


# =============================================================
# 主流程
# =============================================================

def process_file(
    path: Path,
    *,
    dry_run: bool,
    force: bool,
) -> str:
    """处理单个文件，返回状态字符串。"""
    text = path.read_text(encoding="utf-8", errors="replace")
    fields, body = parse_frontmatter(text)

    if fields.get("normalized") is True and not force:
        return "skip (already normalized)"

    # 文件名兜底标题：去掉日期前缀 + .md
    if "title" not in fields and "name" not in fields:
        stem = path.stem
        stem = re.sub(r"^\d{4}-\d{2}-\d{2}-", "", stem)
        fields.setdefault("title", stem)

    new_fields = normalize_fields(fields)
    new_text = render_frontmatter(new_fields) + body.lstrip("\n")

    if dry_run:
        return f"would write ({len(new_text)} bytes)"

    path.write_text(new_text, encoding="utf-8")
    return "normalized"


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("path", type=Path, help="IMA 同步目录（递归处理所有 .md）")
    p.add_argument("--dry-run", action="store_true", help="不写文件，只报告")
    p.add_argument("--force", action="store_true", help="强制 normalize（含已 normalized 的）")
    p.add_argument("--quiet", "-q", action="store_true", help="只打印失败/统计")
    args = p.parse_args(argv)

    if not args.path.exists():
        print(f"ERROR: {args.path} 不存在", file=sys.stderr)
        return 1

    md_files = sorted(args.path.rglob("*.md"))
    if not md_files:
        print(f"WARN: {args.path} 下没有 .md 文件", file=sys.stderr)
        return 0

    stats = {"normalized": 0, "skip": 0, "would write": 0, "error": 0}
    for f in md_files:
        try:
            status = process_file(f, dry_run=args.dry_run, force=args.force)
            short_status = status.split(" ", 1)[0]
            if short_status == "would":
                stats["would write"] += 1
            else:
                stats[short_status] = stats.get(short_status, 0) + 1
            if not args.quiet:
                rel = f.relative_to(args.path)
                print(f"  [{status}] {rel}")
        except Exception as e:
            stats["error"] += 1
            print(f"  [ERROR] {f}: {e}", file=sys.stderr)

    print(f"\n# 共 {len(md_files)} 个文件: " + ", ".join(
        f"{k}={v}" for k, v in stats.items() if v > 0
    ), file=sys.stderr)
    return 0 if stats["error"] == 0 else 2


if __name__ == "__main__":
    sys.exit(main())
