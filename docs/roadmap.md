# 路线图

按"数据源价值密度"排序，每个 Sprint 都能独立交付价值，不必一次全做完。

---

## 整体时间线

| Sprint | 目标 | 依赖 | 预计时间 | 产出 |
|--------|------|------|---------|------|
| **S1** | 公众号 → wiki 全链路 | 无 | 1 晚 ~2h | IMA 三引擎 + 公众号自动入库 |
| **S2** | 历史研报导入 + wiki 定制 | S1 | 半晚 ~1h | 存量 PDF 利用起来；定 purpose/schema |
| **S3** | 知识星球增量同步 | S1 | 1 晚 ~1.5h | 付费星球内容自动入库 |
| **S4** | 精选 2-3 个微信群入库 | S1 | 2 晚 ~3-4h | 群里讨论沉淀 |
| **S5** | 双引擎查询习惯 + 关键词通知 | S1+ | 持续 | 把整套用顺 |

---

## Sprint 1 · 公众号链路打通

### 用户做（按顺序）

1. 装 IMA（`ima.qq.com` 或微信小程序"ima 知识库"）
2. 订阅 IMA 知识库：
   - **腾讯财经"最全研报知识库"**（公共）
   - **三余的行业知识库**（朋友策展，shareId 群里给）
3. 在 IMA 各 @ 一次问 3 个最近真正纠结的问题（验证质量）
4. 从 [trading-review-wiki Releases](https://github.com/ymj8903668-droid/trading-review-wiki/releases) 下 `.dmg` 装到 Mac
5. 装 Obsidian + 插件 [`ima.copilot Sync`](https://community.obsidian.md/plugins/ima-copilot-sync)，填 IMA Client ID / API Key
6. 把 Obsidian Vault 路径设成 `~/wiki/raw/sources/wechat-mp/`

### 仓库交付（agent 写好）

- `prompts/wiki-ingest-system.md` — 喂给 trading-review-wiki 的系统提示
- `docs/friend-onboarding.md` — 朋友 3 步加入文档

### 完成标志

在 IMA 里存一篇公众号文章，1 小时内 Obsidian 收到同步，下次 trading-review-wiki 摄入队列能看到，`wiki/股票/` 下出现自动生成页。

---

## Sprint 2 · 历史 PDF + wiki 定制

### 用户做

1. 从硬盘翻历史研报、笔记、PDF（按板块/题材简单归个文件夹）
2. 在 trading-review-wiki 里"文件夹导入"
3. 跑完后做一遍 Wiki Doctor 整理

### 仓库交付

- `templates/purpose.md` — A 股研究 wiki 的目标、关键问题、研究范围
- `templates/schema.md` — A 股研究的页面类型规则（股票、题材、模式、错误、人物、事件）
- `docs/research-folder-guide.md` — 历史研报"按板块归档"目录结构建议

---

## Sprint 3 · 知识星球同步

### 用户做

1. 列出已订阅的 1-3 个高质量星球
2. 浏览器登录知识星球网页版，DevTools 拷 Cookie 里的 `access_token`
3. 装 [`uv`](https://github.com/astral-sh/uv)（Python 工具链），clone ZsxqCrawler 仓库
4. 跑首次全量同步，验证 `output/articles/` 有 md

### 仓库交付

- `scripts/zsxq/config.toml.example` — 配置模板（含占位符）
- `scripts/zsxq/zsxq_daily.sh` — 增量同步 + 软链入库
- `configs/launchd/zsxq-daily.plist.example` — macOS 定时任务
- `docs/zsxq-cookie-sop.md` — Cookie 过期 30 秒恢复 SOP

---

## Sprint 4 · 微信群入库

### 用户做

1. 精选 2-3 个高质量资讯群，告诉 agent 群名（占位符即可）
2. 装 [`wechat-digest`](https://github.com/cliffyan28/wechat-digest)，跑 `init-keys.py`（微信要在运行）
3. 首次跑一天的提取，看输出 md 包不包含目标群
4. 用清洗脚本跑一遍，对比清洗前后效果
5. 验证 trading-review-wiki 自动摄入

### 仓库交付

- `scripts/wechat/wechat_clean.py` — 群聊清洗（去 emoji / 合并连续短消息 / 可选脱敏）
- `scripts/wechat/wechat_daily.sh` — 提取 + 清洗 + 软链 + 通知主脚本
- `configs/launchd/wechat-daily.plist.example` — 每日 23:00 定时
- `docs/wechat-keys-sop.md` — 密钥失效 SOP

---

## Sprint 5 · 整合 + 持续优化

### 使用习惯

- **每天早上**：IMA 看公共研报共识；wiki 看自己昨天新摄入的页面
- **每周末**：在 wiki 里做一次 Lint，看孤立页 / 桥接节点 / 知识空白
- **关键题材**：用 wiki 知识图谱看演变脉络

### 可选增强（按需启用）

- 装 [`wechat-mcp`](https://github.com/Cybing521/wechat-mcp)，关键词命中走 macOS 通知
- 配 Tavily API Key 启用 Deep Research
- 把 wiki 高频访问页归档到 IMA（手机随时查）
- 调 LLM Provider：高频用 DeepSeek 省钱，复杂分析切 Claude

---

## 完成判据 / 何时算"建好了"

| 维度 | 标准 |
|------|------|
| 自动化 | 每天 23:00 自动同步知识星球 + 微信群；早上起来就有新 wiki 页面 |
| 覆盖率 | 重要公众号 / 星球 / 群的内容都能进库 |
| 查询质量 | 同一个问题，wiki 比纯豆包/通用 LLM 答得更具体、有来源 |
| 朋友体验 | 新朋友按 friend-onboarding.md 走，3 步内能跑起来 |
| 维护成本 | 每月 < 30 分钟（处理 Cookie / 密钥过期） |
