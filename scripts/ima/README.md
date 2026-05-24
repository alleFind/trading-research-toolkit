# scripts/ima — 公众号链路（IMA → Obsidian → wiki）

> 把公众号文章无脚本、无爬虫地落到 trading-review-wiki 的 `raw/sources/wechat-mp/`。

## 链路

```
微信公众号
   ↓ "分享到 IMA"
腾讯 IMA 云端知识库
   ↓ Obsidian 插件 `ima.copilot Sync`（拉）
Obsidian Vault: $VAULT/IMA/
   ↓ ima_link.sh （建一次软链，永久生效）
trading-review-wiki: $WIKI/raw/sources/wechat-mp/
   ↓ 应用自动扫描 + LLM 摄入
wiki/资料/ + wiki/股票/ + wiki/题材/...
```

完整 SOP（含安装、登录、第一次配置）见 [`docs/ima-obsidian-pipeline.md`](../../docs/ima-obsidian-pipeline.md)。

## 文件清单

| 文件 | 作用 |
|---|---|
| `ima_link.sh` | 一次性建 Obsidian vault ↔ wiki 软链；带 `--check` 做健康检查 |
| `normalize_ima.py` | 把 IMA 同步插件的 frontmatter 规范化成 schema.md 期望的格式 |
| `README.md` | 本文 |

## 快速上手

### 第一次接入（5 步）

1. 微信 + IMA 移动端/桌面端登好，新建一个知识库（建议 "A股研究"）
2. Obsidian 装好，装 `ima.copilot Sync` 插件，同步到 vault 内 `IMA/` 子目录
3. trading-review-wiki 项目目录已初始化（参考 `scripts/wiki/setup_wiki.sh`）
4. 跑：

   ```bash
   ./scripts/ima/ima_link.sh \
     --vault ~/ObsidianVault/A股研究 \
     --wiki  ~/wiki
   ```

5. 第一次（可选）跑一次 frontmatter 规范化：

   ```bash
   ./scripts/ima/normalize_ima.py ~/ObsidianVault/A股研究/IMA
   ```

完成。**之后所有动作只剩一个：微信里看到好文章 → 分享 → IMA**。

### 日常健康检查

```bash
./scripts/ima/ima_link.sh --wiki ~/wiki --check
```

退出码：
- `0` 软链 OK
- `2` 软链存在但 broken（vault 路径动过 / 移走过）
- `3` 是普通目录而非软链（之前没用 ima_link 创建）
- `4` 不存在

### 让 normalize 自动跑

> Obsidian 同步插件每 5 分钟拉一次新内容；不想手动跑 normalize？

#### macOS launchd

参考 `configs/launchd/zsxq-daily.plist.example` 的结构，自己写一个 `ima-normalize.plist`，每小时跑一次：

```xml
<key>StartCalendarInterval</key>
<dict>
    <key>Minute</key>
    <integer>0</integer>
</dict>
```

ProgramArguments 调用：

```
/usr/bin/python3 /Users/USERNAME/code/trading-research-toolkit/scripts/ima/normalize_ima.py /Users/USERNAME/ObsidianVault/A股研究/IMA --quiet
```

#### 更简单：让 trading-review-wiki 直接吃 raw 文件

`normalize_ima.py` 不是必须的——trading-review-wiki 的 LLM 摄入对 frontmatter 容忍度很高，没规范化也能跑。规范化只是让 wiki 后续生成的 `资料/` 摘要页字段更整齐。

## normalize_ima.py 工作原理

### 输入（IMA 同步插件的常见输出）

```yaml
---
title: 中际旭创业绩超预期
publisher: 某券商研究
link: https://mp.weixin.qq.com/s?__biz=MzABCD&mid=2247484567&idx=1&sn=abc&chksm=xxx&scene=27&exportkey=AB
created_at: 2026-05-24T09:31:42+08:00
tags: [光模块, AI算力]
doc_id: ima_doc_xyz
---
```

### 输出（规范化后）

```yaml
---
type: raw_source
source_type: wechat-mp
title: 中际旭创业绩超预期
source: 某券商研究
url: "https://mp.weixin.qq.com/s?__biz=MzABCD"
clipped_at: 2026-05-24
tags: [光模块, AI算力]
ima_doc_id: ima_doc_xyz
normalized: true
---
```

变化：

| 项 | 之前 | 之后 | 为什么 |
|---|---|---|---|
| `type` | 缺 | `raw_source` | schema.md 要求 |
| `source_type` | 缺 | `wechat-mp` | wiki 索引按来源类型分组 |
| `publisher` | `某券商研究` | `source: 某券商研究` | 跟 schema.md 统一字段名 |
| `link` | 全 tracking URL | `__biz` 留，其余去 | 一篇文章一份 URL，方便去重 |
| `created_at` | ISO 时间戳 | `clipped_at: YYYY-MM-DD` | 只需要日期粒度 |
| `doc_id` | `ima_doc_xyz` | `ima_doc_id: ima_doc_xyz` | 可追溯 IMA 原文 |
| 全部 | — | + `normalized: true` | 幂等：下次跑直接跳过 |

### 字段别名兼容

`normalize_ima.py` 顶部 `FIELD_ALIASES` 维护映射，IMA 任何版本的字段名变化只需要加一行：

```python
FIELD_ALIASES = {
    "title":      ["title", "name", "Title"],
    "source":     ["source", "author", "publisher", "公众号", "from"],
    "url":        ["url", "link", "原文链接", "source_url"],
    ...
}
```

### URL 清洗规则

公众号 URL 上典型的 tracking 参数都会去掉：

```
__biz       ← 保留（文章定位 key）
mid         ← 删
idx         ← 删
sn          ← 删
chksm       ← 删
scene       ← 删
subscene    ← 删
clicktime   ← 删
exportkey   ← 删
pass_ticket ← 删
key, uin    ← 删（个人鉴权信息！）
...
```

完整黑名单见 `normalize_ima.py` 顶部 `URL_DROP_PARAMS`。

## 故障排查

### `--check` 报 BROKEN

vault 路径动过。重新跑 link：

```bash
rm ~/wiki/raw/sources/wechat-mp
./scripts/ima/ima_link.sh --vault <新路径> --wiki ~/wiki
```

### `--check` 报"是普通目录而非软链"

之前手动 `cp -r` 或别的工具创建过。如果里面没有重要文件，删掉重新软链：

```bash
mv ~/wiki/raw/sources/wechat-mp ~/wiki/raw/sources/wechat-mp.old
./scripts/ima/ima_link.sh --vault ... --wiki ~/wiki
```

### IMA 同步不出新文件

不是 normalize 的问题——Obsidian 同步链路本身。打开 Obsidian → ima.copilot Sync 设置 → 点"立即同步" → 看日志。

### normalize 之后正文丢了

不应该发生，本脚本只重写 frontmatter，正文 `body = text[m.end():]` 完整保留。如果真发生：

1. `git status` 看是否有 `.md.bak` —— 没做备份（脚本默认就地改）
2. Obsidian sync 插件下次会重新拉一份原始
3. 万一彻底丢了，去 IMA 桌面端再次同步

> 建议第一次跑前先 `cp -r ~/ObsidianVault/A股研究/IMA /tmp/ima-backup-$(date +%F)`，保险一手。

## 安全提醒

- IMA 是腾讯云服务，转发到 IMA 的文章会上云（**公众号文章本身就是公开内容**，但你加的私人 tag 和笔记也会同步）
- 不要在 IMA 里写敏感信息（持仓、家庭情况、客户关系等）
- `ima_doc_id` 包含 IMA 内部 ID，不算敏感，但分享 wiki 给朋友前可以一并 strip 掉（手工 / 写个 sed）
