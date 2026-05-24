# trading-research-toolkit

> 私人 A 股研究知识库的"方法 + 工具"仓库。

不是知识库本身，是**搭建自己知识库的所有脚本、配置、模板和约定**。每个人 clone 一份在自己 Mac 上跑，私货留本地，方法在仓库共享。

---

## 这是什么

一套帮你把以下数据源**自动汇聚 + 用 LLM 整理成结构化知识库**的工具集：

- 微信公众号文章（通过 IMA → Obsidian → 本地）
- 知识星球付费内容（ZsxqCrawler 增量抓取）
- 精选微信群聊天（wechat-digest 解密 + 清洗）
- 历史研报 PDF（拖拽导入）

最终所有数据进入 [trading-review-wiki](https://github.com/ymj8903668-droid/trading-review-wiki) 桌面 App，让 LLM 持续编译成"个股 / 板块 / 题材"结构化 wiki。

查询时三引擎并用：

| 入口 | 用途 |
|------|------|
| trading-review-wiki 聊天 | 自己沉淀的私货（最准） |
| IMA `@腾讯财经研报库` | 公开研报、市场共识 |
| IMA `@三余的行业知识库` | 朋友圈策展的行业精选 |

---

## 仓库结构

```
trading-research-toolkit/
├── README.md                   ← 看这里
├── CHANGELOG.md
├── docs/
│   ├── architecture.md         整体架构和数据流
│   ├── roadmap.md              Sprint 路线图
│   └── friend-onboarding.md    朋友 3 步加入
├── templates/
│   ├── purpose.md              A 股研究 wiki 的目的（拷进你的 wiki 根目录）
│   └── schema.md               A 股研究 wiki 的结构规则
├── prompts/
│   └── wiki-ingest-system.md   trading-review-wiki LLM 摄入的系统提示
├── scripts/                    （按 Sprint 逐步添加）
│   ├── wechat/                 S4：群聊提取+清洗
│   ├── zsxq/                   S3：知识星球同步
│   └── common/                 通用工具（软链入库等）
└── configs/                    （按 Sprint 逐步添加）
    ├── launchd/                macOS 定时任务模板
    └── cron/                   Linux cron 模板
```

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
              腾讯财经研报库 + 三余的行业知识库
```

- ✅ 私货 100% 本地，互不干扰
- ✅ 方法和工具版本同步，谁优化都受益
- ✅ 朋友加入 3 步：clone + 装 wiki + 订阅 IMA

详见 [docs/friend-onboarding.md](docs/friend-onboarding.md)。

---

## 快速开始

### 你已经在用本工具集

1. `git pull` 更新最新脚本
2. 看 [CHANGELOG.md](CHANGELOG.md) 有没有新东西要拉

### 你是新加入的朋友

按 [docs/friend-onboarding.md](docs/friend-onboarding.md) 走 3 步。

---

## Sprint 进度

| Sprint | 内容 | 工时 | 状态 |
|--------|------|------|------|
| S1 | 公众号 → wiki 全链路 | ~2h | 🟡 待动手 |
| S2 | 历史 PDF + wiki 定制 | ~1h | 🟡 待动手 |
| S3 | 知识星球增量同步 | ~1.5h | 🟡 待动手 |
| S4 | 精选微信群入库 | ~3-4h | 🟡 待动手 |
| S5 | 双引擎查询 + 实时通知 | 持续 | ⚪ 未开始 |

详细见 [docs/roadmap.md](docs/roadmap.md)。

---

## 技术栈

| 组件 | 工具 |
|------|------|
| 知识库桌面端 | [trading-review-wiki](https://github.com/ymj8903668-droid/trading-review-wiki)（Tauri） |
| 公众号入口 | 腾讯 IMA + [`ima.copilot Sync`](https://community.obsidian.md/plugins/ima-copilot-sync) Obsidian 插件 |
| 知识星球抓取 | [2dot4/ZsxqCrawler](https://github.com/2dot4/ZsxqCrawler) |
| 微信群提取 | [cliffyan28/wechat-digest](https://github.com/cliffyan28/wechat-digest) |
| 微信群实时盯 | [Cybing521/wechat-mcp](https://github.com/Cybing521/wechat-mcp)（可选） |
| LLM | Claude（主）+ DeepSeek（备用） |
| 定时调度 | macOS launchd / Linux cron |

---

## License

私有仓库。仅限本组使用。

数据源涉及：付费星球内容、微信群聊天、个人交易记录。**严禁公开任何抓取数据**。脚本和模板部分可在征得本组同意后开源。
