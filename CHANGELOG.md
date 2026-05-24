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

### Pending（按 Sprint）
- S4：`scripts/wechat/wechat_clean.py` + `wechat_daily.sh` + launchd plist
- S5：wechat-mcp 配置模板、Tavily 深度研究接入说明
