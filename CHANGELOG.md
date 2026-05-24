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

### Pending（按 Sprint）
- S1：IMA → Obsidian → trading-review-wiki 摄入链路
- S2：历史 PDF / 研报导入 + LLM Provider / purpose.md / schema.md 定制
- S5：wechat-mcp 关键词通知、Tavily 深度研究接入、双引擎查询习惯
