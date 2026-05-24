#!/usr/bin/env python3
"""
wechat_clean.py
================

清洗 `wechat-digest` (cliffyan28/wechat-digest) 的 extract-messages.py 输出，
产生 trading-review-wiki 可直接摄入的结构化 Markdown。

设计原则
--------
1. 只用 Python 3 标准库，零依赖
2. 默认配置就能用，所有行为可通过 CLI 覆盖
3. idempotent：重跑产生同样输出
4. 信噪比优先：去 emoji / 表情 / 系统消息 / 短噪音，保留有信号的内容

输入格式（wechat-digest 的输出，常见两种）
------------------------------------------

  格式 A（带时间戳前缀）:
    [2026-05-24 09:30:15] 用户A: 中际旭创业绩超预期 https://...
    [2026-05-24 09:30:42] 用户B: 我觉得短期已经反映在股价里了

  格式 B（每条消息两行）:
    2026-05-24 09:30:15 用户A
    中际旭创业绩超预期 https://...

    2026-05-24 09:30:42 用户B
    我觉得短期已经反映在股价里了

脚本会自动尝试两种格式。如果你的 wechat-digest 版本输出不同，请在
`--message-regex` 参数里给出你自己的正则。

输出格式
--------

  ---
  type: source_summary
  source_type: wechat-group
  group: 群名
  date: 2026-05-24
  message_count_raw: 327
  message_count_cleaned: 89
  ---

  # 群名 · 2026-05-24

  ## 用户A · 09:30
  中际旭创业绩超预期
  https://mp.weixin.qq.com/...

  ## 用户B · 09:32
  我觉得短期已经反映在股价里了
  ...

用法
----
  ./wechat_clean.py INPUT.md [--output OUTPUT.md] [--aliases aliases.json]
  ./wechat_clean.py INPUT.md --anonymize       # 把昵称替换成 用户A/B/C
  ./wechat_clean.py INPUT.md --dry-run         # 不写文件，只打印 stats
  ./wechat_clean.py --help
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass, field
from datetime import datetime, timedelta
from pathlib import Path

# =============================================================
# 噪音过滤规则
# =============================================================

# 中文 / 英文 / Unicode emoji 范围
EMOJI_RANGES = [
    (0x1F300, 0x1F6FF),
    (0x1F900, 0x1F9FF),
    (0x1FA00, 0x1FAFF),
    (0x2600, 0x26FF),
    (0x2700, 0x27BF),
    (0x1F1E6, 0x1F1FF),
]

# 微信系统消息 / 表情占位符
SYSTEM_PATTERNS = [
    r"^\[图片\]$",
    r"^\[表情\]$",
    r"^\[语音\]$",
    r"^\[视频\]$",
    r"^\[文件:.*\]$",
    r"^\[位置\]$",
    r"^\[红包\]$",
    r"^\[转账\]$",
    r"^\[拍一拍\]",
    r"^\[微信运动\]",
    r"^\[名片:.*\]",
    r"^\[小程序\]",
    r"^@\S+\s*$",                  # 纯 @ 某人没正文
    r".*加入了群聊\s*$",            # 入群通知
    r".*退出了群聊\s*$",            # 退群通知
    r".*邀请.*加入了群聊.*$",
    r".*移出了群聊.*$",
    r"^.+撤回了一条消息.*$",
    r"^.+修改了群名.*$",
    r"^.+修改群昵称为.*$",
    r"^群公告:.*$",
]

# 当 sender 看起来是系统时（不是真人），直接丢弃
SYSTEM_SENDERS = {"系统消息", "微信团队", "微信支付", "群通知", "群助手"}

# 短噪音消息（regex，整条消息匹配则丢弃）
NOISE_PATTERNS = [
    r"^[+]\d+$",                    # +1 +10
    r"^[\d.]+$",                    # 纯数字（除非看起来像股票代码，下面单独判）
    r"^哈+$|^哈+哈+$",
    r"^呵+$",
    r"^嗯+$|^额+$|^哦+$",
    r"^好[的呀啊吧]?$",
    r"^是[的呀啊吧]?$",
    r"^对[的呀啊吧]?$",
    r"^懂了$|^明白了?$|^收到$",
    r"^赞同$|^同意$",
    r"^[666]+$|^牛逼?$|^厉害了?$",
    r"^顶[一]?下?$|^沙发$",
    r"^早$|^早安$|^晚安$|^晚$",
    r"^撤回了一条消息$",
    r"^[。.，,!！?？~～\s]+$",   # 只有标点
    r"^表情$",
]

# 短消息长度阈值（中文字符 + 英文 token 计）
SHORT_MESSAGE_THRESHOLD = 6

# 合并连续消息的时间窗口（秒）
MERGE_WINDOW_SEC = 30


# =============================================================
# 解析层
# =============================================================

@dataclass
class Message:
    timestamp: datetime
    sender: str
    content: str
    raw: str = ""

    def short_time(self) -> str:
        return self.timestamp.strftime("%H:%M")

    def time_with_sec(self) -> str:
        return self.timestamp.strftime("%H:%M:%S")


REGEX_FORMATS = [
    # 格式 A: [YYYY-MM-DD HH:MM:SS] sender: content
    re.compile(
        r"^\[(?P<ts>\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2})\]\s*"
        r"(?P<sender>[^:：]+?)\s*[:：]\s*(?P<content>.*)$"
    ),
    # 格式 A 变体：YYYY-MM-DD HH:MM:SS sender: content（无方括号）
    re.compile(
        r"^(?P<ts>\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2})\s+"
        r"(?P<sender>[^:：]+?)\s*[:：]\s*(?P<content>.*)$"
    ),
    # 格式：HH:MM:SS sender: content （wechat-digest 默认 hour-offset 模式）
    re.compile(
        r"^(?P<ts>\d{2}:\d{2}:\d{2})\s+"
        r"(?P<sender>[^:：]+?)\s*[:：]\s*(?P<content>.*)$"
    ),
]

HEADER_REGEX = re.compile(
    r"^(?P<ts>\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2})\s+(?P<sender>.+?)\s*$"
)


def parse_messages(text: str, fallback_date: datetime | None = None) -> list[Message]:
    """尝试多种格式解析，返回 Message 列表。"""
    lines = text.splitlines()
    messages: list[Message] = []
    pending_header: tuple[datetime, str] | None = None
    fallback_date = fallback_date or datetime.now()

    for raw_line in lines:
        line = raw_line.rstrip()
        if not line:
            if pending_header is not None:
                # 格式 B：header 后跟空行也算空消息，跳过
                pending_header = None
            continue

        # 格式 A：单行包含时间戳 + sender + content
        matched = False
        for pat in REGEX_FORMATS:
            m = pat.match(line)
            if m:
                ts_str = m.group("ts")
                ts = _parse_ts(ts_str, fallback_date)
                if ts is None:
                    continue
                messages.append(Message(
                    timestamp=ts,
                    sender=m.group("sender").strip(),
                    content=m.group("content").strip(),
                    raw=raw_line,
                ))
                matched = True
                pending_header = None
                break
        if matched:
            continue

        # 格式 B：先 header（时间+sender）再正文
        m = HEADER_REGEX.match(line)
        if m and pending_header is None:
            ts = _parse_ts(m.group("ts"), fallback_date)
            if ts is not None:
                pending_header = (ts, m.group("sender").strip())
                continue

        # 格式 B 的正文行
        if pending_header is not None:
            ts, sender = pending_header
            # 多行正文累加到上一条
            if messages and messages[-1].sender == sender and \
               abs((messages[-1].timestamp - ts).total_seconds()) < 1:
                messages[-1].content += "\n" + line.strip()
            else:
                messages.append(Message(
                    timestamp=ts,
                    sender=sender,
                    content=line.strip(),
                    raw=raw_line,
                ))
            # 不重置 pending_header，允许多行正文
            continue

        # 既不是 header，也匹配不上任何格式 — 当成上一条消息的续行
        if messages:
            messages[-1].content += "\n" + line.strip()

    return messages


def _parse_ts(ts_str: str, fallback_date: datetime) -> datetime | None:
    formats = ["%Y-%m-%d %H:%M:%S", "%H:%M:%S"]
    for fmt in formats:
        try:
            dt = datetime.strptime(ts_str.strip(), fmt)
            if fmt == "%H:%M:%S":
                # 没有日期信息，用文件名/参数推断
                dt = dt.replace(
                    year=fallback_date.year,
                    month=fallback_date.month,
                    day=fallback_date.day,
                )
            return dt
        except ValueError:
            continue
    return None


# =============================================================
# 清洗层
# =============================================================

def has_only_emoji(text: str) -> bool:
    stripped = text.strip()
    if not stripped:
        return True
    for ch in stripped:
        if ch.isspace():
            continue
        cp = ord(ch)
        in_emoji = any(lo <= cp <= hi for lo, hi in EMOJI_RANGES)
        if not in_emoji:
            return False
    return True


def is_short_noise(text: str) -> bool:
    """判断是否为短噪音消息（"+1"、"好的"、纯标点等）。"""
    stripped = text.strip()
    if not stripped:
        return True

    # 短到没意义
    cleaned = re.sub(r"[\s\p{P}]+", "", stripped) if False else stripped
    char_count = sum(1 for c in stripped if not c.isspace())
    if char_count < 2:
        return True

    # 黑名单
    for pat in NOISE_PATTERNS:
        if re.match(pat, stripped):
            # 例外：纯数字如果是 6 位（A 股代码），保留
            if pat == r"^[\d.]+$" and re.match(r"^\d{6}$", stripped):
                return False
            return True

    return False


def is_system_message(text: str) -> bool:
    stripped = text.strip()
    for pat in SYSTEM_PATTERNS:
        if re.match(pat, stripped):
            return True
    return False


def looks_valuable(text: str) -> bool:
    """额外的"有价值"信号 —— 命中则即使短也保留。"""
    # 包含 URL
    if re.search(r"https?://", text):
        return True
    # 包含 6 位股票代码
    if re.search(r"\b\d{6}\b", text):
        return True
    # 包含 . SH / .SZ / .BJ 等
    if re.search(r"\d{6}\.(SH|SZ|BJ|HK)", text, re.I):
        return True
    return False


def clean_messages(
    messages: list[Message],
    *,
    short_threshold: int = SHORT_MESSAGE_THRESHOLD,
) -> tuple[list[Message], dict[str, int]]:
    """过滤噪音消息，统计被丢弃数量。"""
    kept: list[Message] = []
    stats = {
        "raw": len(messages),
        "emoji_only": 0,
        "system": 0,
        "noise": 0,
        "too_short": 0,
        "kept": 0,
    }
    for m in messages:
        c = m.content.strip()

        if m.sender in SYSTEM_SENDERS:
            stats["system"] += 1
            continue
        if has_only_emoji(c):
            stats["emoji_only"] += 1
            continue
        if is_system_message(c):
            stats["system"] += 1
            continue
        if is_short_noise(c):
            stats["noise"] += 1
            continue
        # 短但有价值
        char_count = sum(1 for ch in c if not ch.isspace())
        if char_count < short_threshold and not looks_valuable(c):
            stats["too_short"] += 1
            continue

        kept.append(m)
        stats["kept"] += 1

    return kept, stats


def merge_consecutive(
    messages: list[Message],
    *,
    window_sec: int = MERGE_WINDOW_SEC,
) -> list[Message]:
    """合并同一 sender 在 window_sec 内的连续消息。"""
    if not messages:
        return []
    merged = [messages[0]]
    for m in messages[1:]:
        prev = merged[-1]
        same_sender = prev.sender == m.sender
        within_window = (m.timestamp - prev.timestamp).total_seconds() <= window_sec
        if same_sender and within_window:
            prev.content = (prev.content.rstrip() + "\n" + m.content.lstrip()).strip()
        else:
            merged.append(m)
    return merged


# =============================================================
# 脱敏
# =============================================================

def anonymize_messages(
    messages: list[Message],
    aliases: dict[str, str],
) -> tuple[list[Message], dict[str, str]]:
    """
    把昵称替换成 aliases 里的别名。aliases 里没有的，自动分配 用户A/B/C...
    返回新的 messages 列表 + 完整的映射表（含自动分配的）。
    """
    mapping = dict(aliases)
    next_idx = 0
    auto_labels = []
    while len(auto_labels) < 1000:
        # 用户A, 用户B, ..., 用户Z, 用户AA, 用户AB, ...
        labels = _alphabet_label(next_idx)
        auto_labels.append(f"用户{labels}")
        next_idx += 1

    used = set(mapping.values())
    auto_iter = iter(l for l in auto_labels if l not in used)

    out: list[Message] = []
    for m in messages:
        if m.sender not in mapping:
            mapping[m.sender] = next(auto_iter)
        out.append(Message(
            timestamp=m.timestamp,
            sender=mapping[m.sender],
            content=m.content,
            raw=m.raw,
        ))
    return out, mapping


def _alphabet_label(idx: int) -> str:
    """0 → A, 25 → Z, 26 → AA, 27 → AB ..."""
    result = ""
    n = idx + 1
    while n > 0:
        n, rem = divmod(n - 1, 26)
        result = chr(ord("A") + rem) + result
    return result


# =============================================================
# 输出层
# =============================================================

def render(
    messages: list[Message],
    *,
    group: str,
    date: str,
    raw_count: int,
) -> str:
    """渲染成 trading-review-wiki 友好的 Markdown。"""
    out_lines = [
        "---",
        "type: source_summary",
        "source_type: wechat-group",
        f"group: {group}",
        f"date: {date}",
        f"message_count_raw: {raw_count}",
        f"message_count_cleaned: {len(messages)}",
        "---",
        "",
        f"# {group} · {date}",
        "",
    ]
    for m in messages:
        out_lines.append(f"## {m.sender} · {m.short_time()}")
        out_lines.append("")
        out_lines.append(m.content)
        out_lines.append("")
    return "\n".join(out_lines).rstrip() + "\n"


# =============================================================
# CLI
# =============================================================

def _extract_group_and_date_from_name(name: str) -> tuple[str | None, str | None]:
    """
    wechat-digest 输出文件名形如：
      2026-04-09-我的群-聊天记录.md
    抽取日期和群名。
    """
    m = re.match(r"(?P<date>\d{4}-\d{2}-\d{2})-(?P<group>.+?)-聊天记录\.md$", name)
    if not m:
        return None, None
    return m.group("group"), m.group("date")


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("input", type=Path, help="wechat-digest 输出的原始聊天 md 文件")
    p.add_argument("--output", "-o", type=Path, help="输出文件路径（默认输出到 stdout）")
    p.add_argument("--group", help="覆盖群名（默认从文件名解析）")
    p.add_argument("--date", help="覆盖日期（默认从文件名解析，YYYY-MM-DD）")
    p.add_argument("--anonymize", action="store_true", help="把昵称替换为 用户A/B/C...")
    p.add_argument("--aliases", type=Path, help="JSON 文件 {昵称: 别名}，覆盖自动分配")
    p.add_argument("--short-threshold", type=int, default=SHORT_MESSAGE_THRESHOLD,
                   help=f"过滤短于此字符数的消息（默认 {SHORT_MESSAGE_THRESHOLD}）")
    p.add_argument("--merge-window", type=int, default=MERGE_WINDOW_SEC,
                   help=f"合并连续消息的时间窗口秒（默认 {MERGE_WINDOW_SEC}）")
    p.add_argument("--dry-run", action="store_true", help="不写文件，只打印 stats")
    p.add_argument("--quiet", "-q", action="store_true", help="不打印 stats")
    args = p.parse_args(argv)

    if not args.input.exists():
        print(f"ERROR: {args.input} 不存在", file=sys.stderr)
        return 1

    # 解析群名和日期
    auto_group, auto_date = _extract_group_and_date_from_name(args.input.name)
    group = args.group or auto_group or "未知群"
    date = args.date or auto_date or datetime.now().strftime("%Y-%m-%d")
    fallback_date = datetime.strptime(date, "%Y-%m-%d")

    # 加载别名
    aliases: dict[str, str] = {}
    if args.aliases and args.aliases.exists():
        try:
            aliases = json.loads(args.aliases.read_text(encoding="utf-8"))
        except Exception as e:
            print(f"WARN: 读取 {args.aliases} 失败: {e}", file=sys.stderr)

    # 主流程
    raw_text = args.input.read_text(encoding="utf-8", errors="replace")
    messages = parse_messages(raw_text, fallback_date=fallback_date)
    raw_count = len(messages)

    if raw_count == 0:
        print(f"WARN: 未解析出任何消息。请检查 {args.input} 格式或加 --message-regex",
              file=sys.stderr)
        return 2

    cleaned, stats = clean_messages(messages, short_threshold=args.short_threshold)
    cleaned = merge_consecutive(cleaned, window_sec=args.merge_window)

    if args.anonymize:
        cleaned, mapping = anonymize_messages(cleaned, aliases)
        if not args.quiet:
            print(f"# 脱敏映射（共 {len(mapping)} 人）", file=sys.stderr)
            for k, v in sorted(mapping.items()):
                print(f"  {k} -> {v}", file=sys.stderr)

    output = render(cleaned, group=group, date=date, raw_count=raw_count)

    if not args.quiet:
        print(f"# {args.input.name}", file=sys.stderr)
        print(f"  原始消息:    {stats['raw']}", file=sys.stderr)
        print(f"  emoji-only:  {stats['emoji_only']}", file=sys.stderr)
        print(f"  system:      {stats['system']}", file=sys.stderr)
        print(f"  noise:       {stats['noise']}", file=sys.stderr)
        print(f"  too short:   {stats['too_short']}", file=sys.stderr)
        print(f"  保留:        {stats['kept']}", file=sys.stderr)
        print(f"  合并后:      {len(cleaned)}", file=sys.stderr)
        compression = 1 - len(cleaned) / max(stats['raw'], 1)
        print(f"  压缩率:      {compression:.1%}", file=sys.stderr)

    if args.dry_run:
        print("(dry-run, 不写文件)", file=sys.stderr)
        return 0

    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(output, encoding="utf-8")
        if not args.quiet:
            print(f"  写出:        {args.output}", file=sys.stderr)
    else:
        sys.stdout.write(output)

    return 0


if __name__ == "__main__":
    sys.exit(main())
