# CHANGELOG

按时间倒序记录所有有意义的变更。

格式参考 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)。

---

## [Unreleased]

### Added
- 项目初始化：README、架构文档、路线图、朋友加入流程
- `templates/purpose.md` 和 `templates/schema.md` — A 股研究 wiki 的默认配置
- `prompts/wiki-ingest-system.md` — trading-review-wiki LLM 摄入的系统提示模板
- `.gitignore` — 严格排除所有数据/密钥/Cookie
- **S3 完整交付**:
  - `scripts/zsxq/README.md` — 从拿 Cookie 到完全跑通的完整文档
  - `scripts/zsxq/config.toml.example` — ZsxqCrawler 配置模板（多星球 / 多专栏支持）
  - `scripts/zsxq/zsxq_daily.sh` — 增量同步 + 软链 + 可选 rsync 主脚本
  - `configs/launchd/zsxq-daily.plist.example` — macOS 定时（凌晨 4 点）
  - `configs/systemd/zsxq-daily.{service,timer}.example` — Linux 远端 24×7
  - `docs/zsxq-cookie-sop.md` — Cookie 30 秒恢复 SOP
- **S4 完整交付**:
  - `scripts/wechat/wechat_clean.py` — 零依赖清洗脚本（emoji/系统消息/短噪音过滤、连续消息合并、可选脱敏）
  - `scripts/wechat/wechat_daily.sh` — 抓取→清洗→软链→通知 编排脚本
  - `scripts/wechat/wechat.env.example` — 群名/路径/脱敏配置模板
  - `scripts/wechat/README.md` — 完整设计与用法文档（含规则一览、故障排查、安全提醒）
  - `configs/launchd/wechat-daily.plist.example` — macOS 定时（21:30 盘后）
  - `configs/systemd/wechat-daily.{service,timer}.example` — Linux 桌面环境
  - `docs/wechat-keys-sop.md` — 密钥提取 + 群注册 + 失败排障 SOP
  - `.gitignore` 收紧：`scripts/**/*.env`、`scripts/**/aliases.json`、`configs/systemd/*.{service,timer}`
- **S1 完整交付**（公众号 → IMA → Obsidian → wiki）:
  - `docs/ima-obsidian-pipeline.md` — IMA 装机 / 微信转发 / Obsidian sync 插件 / 软链入库 全 SOP
  - `scripts/ima/normalize_ima.py` — IMA frontmatter 规范化 + 公众号 URL tracking 参数清洗（保留 `__biz`），幂等
  - `scripts/ima/ima_link.sh` — vault ↔ wiki 软链（含 `--check` 健康检查、`--normalize` 链上后顺便规范化）
  - `scripts/ima/README.md` — 设计、规则、故障排查
- **S2 完整交付**（LLM Provider + wiki 工作区初始化）:
  - `docs/llm-provider-routing.md` — DeepSeek 摄入 + Claude 查询双 provider 路由策略；含 trading-review-wiki 实际配置步骤、单次成本推导（DeepSeek 单篇摄入 ~$0.001 vs Claude Sonnet ~$0.05）、API key 申请速查、降级方案
  - `scripts/wiki/setup_wiki.sh` — 一条命令初始化 wiki 工作区：建目录骨架、复制 purpose/schema 模板、生成 index/log/overview、软链 4 个上游数据源（IMA/zsxq/wechat/research）、Obsidian 兼容配置
  - `scripts/wiki/README.md` — 设计原则（幂等、软链、跟 toolkit 解耦、跟 Obsidian 共用）+ 数据流图 + 搬家/分享/朋友 onboarding 指引

### Pending
- S5：双引擎查询习惯（trading-review-wiki + IMA 互查工作流）、wechat-mcp 关键词通知（可选）、迭代
