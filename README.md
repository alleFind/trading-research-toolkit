# trading-research-toolkit

> 私人 A 股研究知识库的"方法 + 工具"仓库。

不是知识库本身，是**搭建自己知识库的所有脚本、配置、模板和约定**。每个人 clone 一份在自己 Mac 上跑，私货留本地，方法在仓库共享。

---

## 这是什么

一套帮你把以下数据源**自动汇聚 + 用 LLM 整理成结构化知识库**的工具集：

- 微信公众号文章 — 腾讯 IMA → Obsidian → 本地
- 知识星球付费内容 — ZsxqCrawler 增量抓取
- 精选微信群聊天 — wechat-digest 解密 + 自研清洗
- 历史研报 PDF — 拖拽导入
- 实时关键词通知 — wechat-mcp 盘中盯群（可选）

最终所有数据进入 [trading-review-wiki](https://github.com/ymj8903668-droid/trading-review-wiki) 桌面 App，让 LLM 持续编译成"个股 / 板块 / 题材 / 模式 / 错误"结构化 wiki。

查询时三引擎并用：

| 入口 | 用途 |
|------|------|
| trading-review-wiki 聊天 | 自己沉淀的私货（最准，离线） |
| IMA `@腾讯财经研报库` | 公开研报、市场共识 |
| IMA `@朋友的策展库` | 朋友圈策展的行业精选 |

具体如何分工：详见 [`docs/dual-engine-workflow.md`](docs/dual-engine-workflow.md)。

---

## 功能矩阵

5 个 Sprint 全部交付，全链路开箱即用：

| 模块 | 状态 | 主要文件 | 文档 |
|---|:---:|---|---|
| **S1 · 公众号链路** | ✅ | `scripts/ima/{normalize_ima.py, ima_link.sh}` | [`docs/ima-obsidian-pipeline.md`](docs/ima-obsidian-pipeline.md) |
| **S2 · LLM Provider + wiki 初始化** | ✅ | `scripts/wiki/setup_wiki.sh` | [`docs/llm-provider-routing.md`](docs/llm-provider-routing.md) |
| **S3 · 知识星球增量同步** | ✅ | `scripts/zsxq/{zsxq_daily.sh, config.toml.example}` | [`docs/zsxq-cookie-sop.md`](docs/zsxq-cookie-sop.md) |
| **S4 · 微信群每日入库** | ✅ | `scripts/wechat/{wechat_clean.py, wechat_daily.sh}` | [`docs/wechat-keys-sop.md`](docs/wechat-keys-sop.md) |
| **S5 · 双引擎查询习惯** | ✅ | (纯文档) | [`docs/dual-engine-workflow.md`](docs/dual-engine-workflow.md), [`docs/weekly-review-checklist.md`](docs/weekly-review-checklist.md) |
| 可选：研报 PDF 批量导入 | ✅ | (用 trading-review-wiki 文件夹导入) | [`docs/research-pdf-ingest.md`](docs/research-pdf-ingest.md) |
| 可选：盘中实时通知 | ✅ | (用 wechat-mcp) | [`docs/wechat-mcp-setup.md`](docs/wechat-mcp-setup.md) |

---

## 整体架构

```
       数据源（自己的）                         工具                    汇集地
─────────────────────────────         ────────────────────       ──────────────────
微信公众号文章 ─┐
              │
              ├──→ 腾讯 IMA ──→ Obsidian ──→ ima_link.sh ──┐
              │   (微信原生转发)   (sync 插件)              │
                                                             │
知识星球 ──→ ZsxqCrawler ──→ zsxq_daily.sh ───────────────┤
            (Cookie 抓取)    (增量 + 软链)                  │
                                                             ├──→ ~/wiki/raw/sources/
精选微信群 ──→ wechat-digest ──→ wechat_clean.py            │            │
             (密钥+解密)        wechat_daily.sh ───────────┤            │
                                                             │            ▼
研报 PDF ──→ 手动整理 ────────────────────────────────────┤    trading-review-wiki
                                                             │       (LLM 摄入)
                                                             │            │
                                                             ▼            ▼
                                                        软链入库     ~/wiki/wiki/
                                                                     股票/题材/...

（可选）wechat-mcp ──→ macOS 通知（盘中关键词命中弹通知，不入库）
```

详细图见 [`docs/architecture.md`](docs/architecture.md)。

---

## 协作模式

**模式 A · 各自独立 + 共享方法**

```
你 Mac                        朋友 Mac
trading-review-wiki           trading-review-wiki
公众号/星球/群（自己的）        公众号/星球/群（自己的）
        │                              │
        └──────── 共享 ────────────────┘
            GitHub 仓库（本仓库）
              脚本 / 配置 / 模板 / prompts
            IMA 共享知识库
              腾讯财经研报库 + 朋友的行业知识库
```

- ✅ 私货 100% 本地，互不干扰
- ✅ 方法和工具版本同步，谁优化都受益
- ✅ 朋友加入 3 步：clone + 装 wiki + 订阅 IMA

详见 [`docs/friend-onboarding.md`](docs/friend-onboarding.md)。

---

## 快速开始

### 0 阶段：装 trading-review-wiki

下载 [trading-review-wiki Releases](https://github.com/ymj8903668-droid/trading-review-wiki/releases/latest) 的 macOS `.dmg`，安装。

### 1 阶段：clone 这个仓库

```bash
cd ~/code  # 任意位置
git clone git@github.com:alleFind/trading-research-toolkit.git
cd trading-research-toolkit
```

### 2 阶段：初始化 wiki 工作区

```bash
./scripts/wiki/setup_wiki.sh ~/wiki
```

会建好 `~/wiki/` 目录骨架（`purpose.md` / `schema.md` / `raw/sources/` / `wiki/股票/...`）。

打开 trading-review-wiki → 创建项目 → 选 `~/wiki` → 设置 → 配置 LLM provider（推荐 DeepSeek 摄入 + Claude Sonnet 查询，详见 [`docs/llm-provider-routing.md`](docs/llm-provider-routing.md)）。

### 3 阶段：按需启用数据源

每个数据源都是独立的，按你最迫切的需求开：

| 想立刻能做 | 跑这个 |
|---|---|
| 公众号文章自动入库 | 按 [`docs/ima-obsidian-pipeline.md`](docs/ima-obsidian-pipeline.md) 装 IMA + Obsidian + sync 插件 |
| 知识星球同步 | 按 [`docs/zsxq-cookie-sop.md`](docs/zsxq-cookie-sop.md) 拿 Cookie，然后 `scripts/zsxq/zsxq_daily.sh` |
| 微信群入库 | 按 [`docs/wechat-keys-sop.md`](docs/wechat-keys-sop.md) 装 wechat-digest，配 `scripts/wechat/wechat.env` |
| 一次性导历史 PDF | 按 [`docs/research-pdf-ingest.md`](docs/research-pdf-ingest.md) 整理 + 放进 `~/research-pdfs/` |
| 盘中关键词通知 | 按 [`docs/wechat-mcp-setup.md`](docs/wechat-mcp-setup.md) 装 wechat-mcp |

数据源软链到 wiki：

```bash
./scripts/wiki/setup_wiki.sh ~/wiki \
  --ima-vault    ~/ObsidianVault/A股研究 \
  --zsxq-dir     ~/zsxq-data \
  --wechat-dir   ~/wechat-data/cleaned \
  --research-dir ~/research-pdfs
```

（脚本幂等，可以反复跑）

### 4 阶段：开始用

- 每天：trading-review-wiki 摄入自动跑（队列持久化、崩溃恢复）
- 每周：跑 [`docs/weekly-review-checklist.md`](docs/weekly-review-checklist.md) 一次 5-10 分钟
- 每月：备份 `~/wiki` + 看 LLM 账单 + 更新工具

---

## 仓库结构

```
trading-research-toolkit/
├── README.md                       ← 看这里
├── CHANGELOG.md
├── docs/                           ← 全部 SOP 和工作流文档
│   ├── architecture.md
│   ├── roadmap.md
│   ├── friend-onboarding.md
│   ├── ima-obsidian-pipeline.md    S1
│   ├── llm-provider-routing.md     S2
│   ├── zsxq-cookie-sop.md          S3
│   ├── wechat-keys-sop.md          S4
│   ├── dual-engine-workflow.md     S5
│   ├── weekly-review-checklist.md  S5
│   ├── wechat-mcp-setup.md         可选
│   └── research-pdf-ingest.md      可选
├── templates/
│   ├── purpose.md                  A 股研究 wiki 的目的
│   └── schema.md                   wiki 结构规则
├── prompts/
│   └── wiki-ingest-system.md       trading-review-wiki LLM 系统提示
├── scripts/
│   ├── ima/                        S1：公众号
│   ├── wiki/                       S2：wiki 初始化
│   ├── zsxq/                       S3：知识星球
│   └── wechat/                     S4：微信群
└── configs/
    ├── launchd/                    macOS 定时任务模板
    └── systemd/                    Linux 定时任务模板
```

---

## 技术栈

| 组件 | 工具 | 角色 |
|------|------|---|
| 知识库桌面端 | [trading-review-wiki](https://github.com/ymj8903668-droid/trading-review-wiki)（Tauri） | LLM 摄入 + 结构化 wiki + 知识图谱 |
| 公众号入口 | 腾讯 IMA + [`ima.copilot Sync`](https://community.obsidian.md/plugins/ima-copilot-sync) Obsidian 插件 | 微信原生分享 → 本地 |
| 知识星球抓取 | [2dot4/ZsxqCrawler](https://github.com/2dot4/ZsxqCrawler) | Cookie 增量同步 |
| 微信群提取 | [cliffyan28/wechat-digest](https://github.com/cliffyan28/wechat-digest) | macOS WeChat 数据库解密 |
| 微信群实时盯 | [Cybing521/wechat-mcp](https://github.com/Cybing521/wechat-mcp)（可选） | 关键词命中通知 |
| LLM（摄入） | DeepSeek V4-Flash（走 Custom endpoint） | 便宜 100x，足够摄入 |
| LLM（查询） | Claude Sonnet 4.6（走 Anthropic） | 中文深度推理 |
| 定时调度 | macOS launchd / Linux systemd | 数据源自动更新 |

---

## License

私有仓库。仅限本组使用。

**数据源涉及**：付费星球内容、微信群聊天、个人交易记录。**严禁公开任何抓取数据**。脚本、配置、模板、文档部分可在征得本组同意后开源。

详细安全提醒散落在各 SOP 末尾的"安全提醒"小节。
