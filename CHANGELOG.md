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

### Pending（按 Sprint）
- S3：`scripts/zsxq/` + `configs/launchd/zsxq-daily.plist.example`
- S4：`scripts/wechat/wechat_clean.py` + `wechat_daily.sh` + launchd plist
- S5：wechat-mcp 配置模板、Tavily 深度研究接入说明
