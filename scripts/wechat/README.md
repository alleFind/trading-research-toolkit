# scripts/wechat — 微信群每日同步

> 把"高质量微信资讯群"每天的讨论沉淀成 trading-review-wiki 可摄入的结构化 Markdown。

## 整体思路

```
┌─────────────────┐  init-keys   ┌──────────────────┐
│ WeChat 进程内存 │ ───────────▶ │ ~/.wechat-digest │
│ (SQLCipher 4)   │              │  /all_keys.json  │
└─────────────────┘              └────────┬─────────┘
                                          │
                                          ▼
                              ┌──────────────────────┐
                              │ extract-messages.py  │
                              │ (wechat-digest)      │
                              └────────┬─────────────┘
                                       │ output/
                                       │   2026-05-24-A股研究群-聊天记录.md
                                       ▼
                              ┌──────────────────────┐
                              │ wechat_clean.py      │  ← 本仓库
                              │ - 滤 emoji/系统消息  │
                              │ - 滤短噪音 (+1/好的) │
                              │ - 合并连续消息       │
                              │ - 可选脱敏           │
                              └────────┬─────────────┘
                                       │ cleaned/
                                       │   A股研究群/2026-05-24.md
                                       ▼
                              ┌──────────────────────┐
                              │ ln -s 到             │
                              │ $WIKI_RAW_DIR/       │
                              │   wechat/A股研究群/  │
                              └────────┬─────────────┘
                                       ▼
                              trading-review-wiki LLM 摄入
```

整套链路由 [`wechat_daily.sh`](./wechat_daily.sh) 统一编排，每天通过 launchd / systemd 跑一次。

## 文件清单

| 文件 | 作用 |
|---|---|
| `wechat_clean.py` | 核心清洗脚本（零依赖 Python 3） |
| `wechat_daily.sh` | 每日编排：抓取 → 清洗 → 软链 → 通知 |
| `wechat.env.example` | 配置模板（群名/路径/脱敏开关） |
| `README.md` | 本文 |

定时任务模板见 `../../configs/{launchd,systemd}/wechat-daily.*`。
密钥与初始化详细 SOP 见 `../../docs/wechat-keys-sop.md`。

## 快速上手（5 分钟）

> 前提：你已经按 [`docs/wechat-keys-sop.md`](../../docs/wechat-keys-sop.md) 把 `wechat-digest` 部署好，密钥已落 `~/.wechat-digest/all_keys.json`，群名已写入 `extract-messages.py` 的 `known` 字典。

1. **配置**

   ```bash
   mkdir -p ~/.config/trading-research-toolkit
   cp scripts/wechat/wechat.env.example ~/.config/trading-research-toolkit/wechat.env
   $EDITOR ~/.config/trading-research-toolkit/wechat.env
   ```

   关键字段：

   - `WECHAT_DIGEST_DIR` → `~/wechat-digest`
   - `OUTPUT_DIR` → 任意目录，会按群分子目录
   - `WIKI_RAW_DIR` → 你 trading-review-wiki 的 `raw/sources/`
   - `GROUPS=("A股研究群" "光模块讨论组")` → 注意和 `extract-messages.py` 里 `known` 字典里的 key 完全一致

2. **dry-run 验证**

   ```bash
   export WECHAT_ENV=~/.config/trading-research-toolkit/wechat.env
   ./scripts/wechat/wechat_daily.sh 2026-05-24 --dry-run
   ```

   会打印将要执行的命令但不写文件。

3. **跑一次完整流程**

   ```bash
   ./scripts/wechat/wechat_daily.sh 2026-05-24
   ```

   完成后检查 `$OUTPUT_DIR/A股研究群/2026-05-24.md` 与 `$WIKI_RAW_DIR/wechat/A股研究群` 软链。

4. **排定定时任务**

   - macOS：参考 `configs/launchd/wechat-daily.plist.example`
   - Linux 桌面：参考 `configs/systemd/wechat-daily.{service,timer}.example`

   推荐时间 **21:30**：盘后讨论沉淀完，又赶在睡前出结果。

## wechat_clean.py 进阶用法

### 单文件清洗（不走编排）

```bash
./scripts/wechat/wechat_clean.py \
  ~/wechat-digest/output/2026-05-24-A股研究群-聊天记录.md \
  -o /tmp/cleaned.md
```

stderr 会打印统计信息：

```
# 2026-05-24-A股研究群-聊天记录.md
  原始消息:    327
  emoji-only:  18
  system:      6
  noise:       142
  too short:   42
  保留:        119
  合并后:      89
  压缩率:      72.8%
```

### 调清洗强度

```bash
# 更严：短于 10 字的消息也丢
./wechat_clean.py input.md --short-threshold 10 -o output.md

# 更宽松：保留更多短消息（默认 6）
./wechat_clean.py input.md --short-threshold 3 -o output.md

# 调连续消息合并窗口（默认 30 秒）
./wechat_clean.py input.md --merge-window 60 -o output.md
```

### 脱敏

```bash
# 全自动脱敏：所有昵称 → 用户A/B/C...
./wechat_clean.py input.md --anonymize -o output.md

# 部分指定 + 其它自动
echo '{"老王": "VIP_老王"}' > /tmp/aliases.json
./wechat_clean.py input.md --anonymize --aliases /tmp/aliases.json -o output.md
```

> 个人本地建议**不开**脱敏（保留昵称便于回溯）。要分享给朋友的样本数据再开。

### dry-run（只看 stats）

```bash
./wechat_clean.py input.md --dry-run
```

## 输出 schema

清洗后的每个 `.md` 文件结构：

```markdown
---
type: source_summary
source_type: wechat-group
group: A股研究群
date: 2026-05-24
message_count_raw: 327
message_count_cleaned: 89
---

# A股研究群 · 2026-05-24

## 用户A · 09:30
中际旭创业绩超预期...
https://mp.weixin.qq.com/s/abc

## 用户B · 09:32
我觉得短期已经反映在股价里了...
```

这个 frontmatter 跟 `templates/schema.md` 的 `source_summary` 类型对齐，trading-review-wiki 摄入时可以直接读这些元信息建索引。

## 清洗规则一览

| 类型 | 命中规则 | 例 |
|---|---|---|
| **emoji-only** | 整条消息纯 emoji（Unicode 范围匹配） | 👍 / 🎉🎉🎉 |
| **system** | 微信占位符 / 入群/退群/撤回 / 系统 sender | `[图片]` / `小王加入了群聊` |
| **noise** | "+1"、"哈哈哈"、"666"、"好的"、纯标点 | `666` / `666666` / `。。。` |
| **too-short** | 短于阈值且没有 URL / 股票代码 | `不错` |
| **保留** | 其余 | 任何有信号的讨论 |

例外：

- **6 位数字** 即使纯数字也保留（A 股代码）
- **包含 URL** 即使短也保留
- **包含 `\d{6}\.(SH|SZ|BJ|HK)`** 即使短也保留

需要更复杂的过滤（比如按关键词白名单）？直接编辑 `wechat_clean.py` 顶部的常量区。

## 故障排查

### `WARN: 未解析出任何消息`

`wechat-digest` 的输出格式不是脚本预设的几种之一。两个办法：

1. 把头 5 行贴在 issue 里，我加新格式
2. 临时改 `wechat_clean.py` 里 `REGEX_FORMATS` 加你自己的正则

### `原始文件不存在`

`extract-messages.py` 没跑成功或那天群里真没消息。手动跑一遍 `extract-messages.py` 看错误。

### 抓的群比配的少

`extract-messages.py` 里的 `known` 字典里没注册这个群，或者 chatroom ID 拼错了。

### 合并后消息时间错乱

`--merge-window` 设得太大，把不同话题合并了。调小，或设为 `0` 关闭合并。

### 想看清洗前后对比

```bash
./wechat_clean.py input.md -o /tmp/cleaned.md
diff <(head -200 input.md) <(head -200 /tmp/cleaned.md) | less
```

## 安全提醒

- `wechat.env`、`aliases.json`、`~/.wechat-digest/all_keys.json` **都是高度敏感**。本仓库 `.gitignore` 已排除前两者，密钥目录本就在仓库外。
- 千万**不要**把 `$OUTPUT_DIR` 链到任何同步盘（iCloud / Dropbox / OneDrive），否则原始聊天会跨设备扩散。
- 分享给朋友的应是 wiki 输出（已经 LLM 提炼过、不含可识别身份信息），**不是** raw 文件。
- 详细合规与安全讨论见 `docs/wechat-keys-sop.md` 第 9 节。
