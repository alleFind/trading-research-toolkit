# 架构

## 总览

```
┌──── 各自本地（私货） ────────────────────────────────┐
│                                                       │
│  你的 Mac                朋友 Mac                     │
│  ┌──────────────┐       ┌──────────────┐             │
│  │ 公众号(IMA)  │       │ 公众号(IMA)  │             │
│  │ 知识星球     │       │ 知识星球     │             │
│  │ 精选微信群   │       │ 精选微信群   │             │
│  │ 历史 PDF     │       │ 历史 PDF     │             │
│  └──────┬───────┘       └──────┬───────┘             │
│         ▼                      ▼                     │
│  trading-review-wiki    trading-review-wiki          │
│                                                       │
└──────────┬────────────────────────┬──────────────────┘
           │                        │
           ▼                        ▼
┌──── 共享层（IMA + GitHub） ──────────────────────────┐
│                                                      │
│  IMA 公共订阅:                                       │
│    📚 腾讯财经"最全研报知识库"（100+ 券商）          │
│    📚 三余的行业知识库（朋友策展）                   │
│                                                      │
│  GitHub 仓库 (本仓库):                               │
│    🔧 scripts/（清洗、同步、cron）                   │
│    🔧 configs/（zsxq config.toml / launchd plist）   │
│    🔧 templates/（purpose.md / schema.md）           │
│    🔧 prompts/（清洗用、wiki ingest 用）             │
│                                                      │
└──────────────────────────────────────────────────────┘
```

---

## 数据流水线（4 个阶段）

### ① 采集

| 来源 | 工具 | 频率 |
|------|------|------|
| 微信公众号 | IMA 小程序"保存到知识库" | 看到就存 |
| 知识星球 | ZsxqCrawler `zsxq-md crawl --incremental` | 每天 23:00 |
| 微信群（精选 2-3 个）| wechat-digest `extract-messages.py` | 每天 23:00 |
| 历史 PDF | trading-review-wiki 文件夹导入 | 一次性 |

### ② 同步本地

| 路径 | 用途 |
|------|------|
| `~/wiki/raw/sources/wechat-mp/` | IMA → Obsidian 自动同步的公众号文章 |
| `~/wiki/raw/sources/zsxq/` | 软链自 ZsxqCrawler 的 `output/articles/` |
| `~/wiki/raw/sources/wechat/{群名}/YYYY-MM-DD.md` | 清洗后的群聊 |
| `~/wiki/raw/sources/research/` | 手动归类的历史研报 |

### ③ LLM Wiki 整理

trading-review-wiki 的"两步思维链摄入"：

1. **分析**：LLM 读源文件 → 抽取关键实体、判断与现有 wiki 的关联、提出新页面建议
2. **生成**：LLM 写 wiki 页面 + 交叉引用 + 更新 `index.md` / `overview.md`

输出到 `~/wiki/wiki/` 下的中文目录：
- `wiki/股票/`
- `wiki/题材/`
- `wiki/模式/`
- `wiki/错误/`
- `wiki/人物/`
- `wiki/事件/`

### ④ 多源查询

| 问题类型 | 用哪个 |
|---------|--------|
| 市场共识 / 券商怎么看某板块 | IMA `@腾讯财经研报库` |
| 某行业精选研究 | IMA `@三余的行业知识库` |
| 某题材脉络 / 个股深度 | trading-review-wiki 聊天 |
| 某位大 V 近期观点 | trading-review-wiki 搜索（星球已沉淀）|
| 一手公众号热点 | IMA 个人库 / Obsidian 搜索 |
| 复盘 / 交易决策 | trading-review-wiki 复盘视图 |

---

## 运行环境

| 组件 | 在哪运行 | 原因 |
|------|---------|------|
| trading-review-wiki | **你的 Mac** | Tauri 桌面 GUI |
| 微信群提取 | **你的 Mac** | 微信本地 DB |
| IMA + 公众号订阅 | **你的 Mac + 手机** | 绑微信账号 |
| ZsxqCrawler | Mac 或 Linux 远端 | 纯 HTTP + Cookie，哪里都行 |
| Git 仓库 | GitHub | 共享中心 |

**推荐**：
- 重度数据处理 + 桌面 App = Mac
- ZsxqCrawler 可选放远端 7×24 跑（Mac 关机也不影响）

---

## 关键设计原则

1. **私货本地，方法共享** — 真实数据从不离开 Mac；脚本/配置/模板放 GitHub
2. **入库原文，摘要不入库** — trading-review-wiki 自己做 LLM 提炼，不预先摘要（精选群信噪比高，原文更值钱）
3. **三引擎查询** — 私货深度（wiki） + 公开广度（腾讯财经） + 圈子精选（三余）
4. **增量优先** — 所有抓取都基于 hash/checksum 跳过未变内容，省 token
5. **失败可恢复** — Cookie 过期、密钥失效都有 30 秒 SOP

---

## 风险与合规

| 风险 | 缓解 |
|------|------|
| 微信群涉及他人隐私 | 仅入精选群；清洗时可选脱敏昵称；不公开分享 |
| 知识星球付费内容 | 仅用于自己已订阅的星球；不公开分享、不二次售卖 |
| Cookie / 微信密钥 | `.gitignore` 严格排除；定期重置 |
| LLM API Key 泄露 | 永远从环境变量读取，不写死在脚本 |
