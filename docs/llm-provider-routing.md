# LLM Provider 路由策略

> 在 trading-review-wiki 里，**摄入**（ingest）和**查询**（query）是两类完全不同的活儿。用同一个模型跑就是浪费钱。本文给出两套配置，按工作流随时切换。

## 1. 核心结论（先看这个，看完就行动）

| 任务 | 模型 | 月成本估算 (中等使用) |
|---|---|---|
| **摄入** — 公众号 / 星球 / 微信群 / 研报 → wiki 页面 | **DeepSeek V4-Flash** (走 Custom endpoint) | ~$1-3 |
| **查询 + Deep Research** — 你跟 wiki 对话、跨题材分析 | **Claude Sonnet 4.6** (走 Anthropic) | ~$3-10 |
| **(可选) 向量 embedding** — 语义检索 | **OpenAI text-embedding-3-small** | ~$0.1 |

合计 ~$5-15/月，对个人研究强度刚好。重度使用（每天 50 篇 + 100 条查询）也压在 $30/月以内。

详细推导见下面。

---

## 2. 为什么要分两个 provider

### 2.1 摄入的特点

- **量大** — 每篇资料约 3-10K input tokens
- **任务简单** — 提取实体、归类题材、生成摘要、写 frontmatter
- **结构化输出** — JSON-ish 的实体列表 + 几段 markdown
- **可缓存** — system prompt（purpose.md + schema.md）几乎不变，每次都能 cache hit
- **不需要深度推理** — 不是让模型给投资建议，只是把内容归位

→ 适合 **便宜 + 快 + 大 context** 的模型。DeepSeek V4-Flash 是当前性价比之王。

### 2.2 查询的特点

- **量小** — 每天可能就 5-20 个对话
- **任务复杂** — 跨页面综合、找矛盾、推演演变、生成对比表
- **中文为主** — 涉及具体 A 股个股、券商分析师名字、特定题材生态
- **要"深度"** — 你期待的不是检索结果，是"分析师视角"
- **会被 Save to Wiki** — 答得好的回答会被你保存进 wiki，进一步影响后续 wiki 质量

→ 适合 **强推理 + 中文好 + 上下文长** 的模型。Claude Sonnet 4.6 ≈ Opus 80% 的水平，但成本 1/5；DeepSeek V4-Pro Thinking 也行，但用户体验上 Claude 流畅性更好。

### 2.3 单 provider 也能用，但要做妥协

| 单 provider 方案 | 妥协 |
|---|---|
| 全用 Claude Sonnet | 摄入会贵 50-100x（DeepSeek vs Sonnet output: $0.28 vs $15） |
| 全用 DeepSeek Flash | 查询深度不够；中文分析不如 Claude 自然；Save to Wiki 的答案质量受影响 |
| 全用 DeepSeek Pro Thinking | 比 Claude 便宜，但摄入仍然过度（不需要 thinking）；输出有时啰嗦 |
| 全用 OpenAI gpt-4o | 中文能力一般；价格在中间但都不极致 |

---

## 3. 实际定价对比（2026 年 5 月）

| 模型 | Input $/M | Output $/M | Cache Hit Input | 推荐场景 |
|---|---:|---:|---:|---|
| **DeepSeek V4-Flash** | $0.14 | $0.28 | $0.0028 (98% off) | 摄入、批量处理 |
| DeepSeek V4-Pro (promo) | $0.435 | $0.87 | $0.003625 | 深度摄入、长 PDF |
| DeepSeek V4-Pro (list) | $1.74 | $3.48 | $0.0145 | 同上（5/31 后） |
| Claude Haiku 4.5 | $1.00 | $5.00 | $0.10 | 极简查询，量大 |
| **Claude Sonnet 4.6** | $3.00 | $15.00 | $0.30 | 主力查询 + Deep Research |
| Claude Opus 4.7 | $5.00 | $25.00 | $0.50 | 难题专用，按需 |

> 数据源：DeepSeek 官方 / Anthropic 官方，2026-05 价格。Cache Hit 行的意义：当 system prompt 不变（你的 purpose.md + schema.md），重复部分按 cache hit 计费。摄入流程几乎 100% cache hit。

### 摄入一篇典型 5000 字公众号文章的成本

| 模型 | Input (10K cache hit + 2K miss) | Output (3K) | 单篇 |
|---|---:|---:|---:|
| DeepSeek V4-Flash | $0.0000028 + $0.00028 | $0.00084 | **~$0.0011** |
| Claude Sonnet 4.6 | $0.003 + $0.006 | $0.045 | ~$0.054 |
| Claude Opus 4.7 | $0.005 + $0.01 | $0.075 | ~$0.090 |

**结论：DeepSeek 摄入比 Claude Sonnet 便宜 ~50x，比 Opus 便宜 ~80x。** 每天 30 篇文章，月度差距：DeepSeek ~$1 vs Sonnet ~$50 vs Opus ~$80。

### 一次 Deep Research 查询（5 个搜索结果 + 综合）的成本

| 模型 | Input (~30K) | Output (~5K) | 单次 |
|---|---:|---:|---:|
| DeepSeek V4-Pro Thinking | $0.013 | $0.011 | **~$0.024** |
| Claude Sonnet 4.6 | $0.090 | $0.075 | ~$0.165 |
| Claude Opus 4.7 | $0.150 | $0.125 | ~$0.275 |

**结论：查询场景 DeepSeek 仍便宜 6-10x，但 Claude 的分析质量在 A 股深度问题上明显更强。** 个人研究强度（每周 5-10 个 Deep Research）月度差距：Sonnet ~$5 vs Opus ~$10。这点钱**值得花**。

---

## 4. 在 trading-review-wiki 里怎么配

### 4.1 摄入用 DeepSeek（关键：走 Custom endpoint）

> trading-review-wiki 的 PROVIDERS 列表里**没有 DeepSeek 选项**。但 DeepSeek API 是 OpenAI 兼容的，走 `Custom` 即可。

1. 打开 trading-review-wiki → **设置**
2. **LLM 提供商** → 选 `Custom`
3. **Custom Endpoint** 填：

   ```
   https://api.deepseek.com/v1
   ```

4. **API Key** 填你的 DeepSeek key（在 https://platform.deepseek.com/api_keys 申请）
5. **Model** 填：

   ```
   deepseek-chat
   ```

   （= V4-Flash 非思考模式，最便宜，足够做摄入）

   如果要做深度摄入（很长 PDF / 研报）：

   ```
   deepseek-reasoner
   ```

   （= V4-Flash 思考模式，多一点 CoT，处理长结构更好）

6. **Max Context Size** 设到 `131072` (128K) — DeepSeek V4 是 1M context，但摄入一篇文章 30K 够了，给个 128K 留 buffer
7. 保存

设置完后，**资料源**里所有新文件摄入都走 DeepSeek。

### 4.2 查询用 Claude（手动切换）

> 目前 trading-review-wiki 没有"自动按场景切 provider"的功能。需要你切设置——5 秒钟的事。

工作流：

1. 上午 / 摄入完 → 默认保持 DeepSeek
2. 晚上深度复盘、Deep Research、跟 wiki 长聊 → 设置切到：
   - **LLM 提供商**：`Anthropic`
   - **API Key**：你的 Anthropic key（https://console.anthropic.com）
   - **Model**：`claude-sonnet-4-5-20250514`（或新版 4.6 模型 ID）
   - **Max Context Size**：`204800` (200K)
3. 查询 / Deep Research 跑完后，**可以不切回去**——下次摄入再切，无所谓

### 4.3 一个小妥协

每次切 provider 要点 3 下设置。两个解决思路：

**方案 A（推荐）：双项目**

- `~/wiki` — 主项目，平时这个，配 Claude（默认设置即生效）
- `~/wiki-ingest` — 摄入专用项目，软链同一个 `raw/sources/` 和 `wiki/` 目录到这里，但应用项目设置（`.llm-wiki/settings.json` 那一套）独立 → 这个项目配 DeepSeek

  > 但是 trading-review-wiki 的 LLM 设置存在 Tauri Store，是**应用全局**不是 per-project，所以这条路其实不通。

**方案 B（务实）：批量摄入时切**

平时 Claude；要批量摄入时（如清晨补一周公众号）暂时切 DeepSeek，跑完再切回。

**方案 C（最优雅）：自己加 feature**

trading-review-wiki 是开源的，给它提个 PR 加 "per-source-type provider routing"。短期可以 fork 自己加。

→ 当前阶段**用方案 B**，等使用模式稳定再决定要不要 fork。

### 4.4 (可选) Embedding / 向量搜索

如果开启向量搜索（README 提到 LanceDB + 任意 OpenAI 兼容 `/v1/embeddings`）：

- **Endpoint**: `https://api.openai.com/v1`
- **API Key**: OpenAI key
- **Model**: `text-embedding-3-small`（$0.02/1M tokens，几乎免费）

也可以试 DeepSeek 的 embedding 端点（如果他们出了），或本地 Ollama 跑 `nomic-embed-text`（零成本）。

---

## 5. 申请 API key 速查

| Provider | 申请地址 | 充值方式 | 备注 |
|---|---|---|---|
| DeepSeek | https://platform.deepseek.com/api_keys | 支付宝、微信、卡 | 国内付款顺畅；最低充值 ¥10 起 |
| Anthropic | https://console.anthropic.com/settings/keys | 卡（VISA / Mastercard） | 需要海外卡；首充 $5 |
| OpenAI | https://platform.openai.com/api-keys | 卡 | 同上；现充值需要预存 $5 起 |

> 国内：DeepSeek 必选（支付方便、便宜、Chinese-native）；Claude 需要海外卡或代充服务（如 https://www.openai-key.com 这类，但有合规风险，自己评估）。

---

## 6. 配额与 rate limit

| 模型 | 并发上限 | 单分钟 token 上限 |
|---|---:|---:|
| DeepSeek V4-Flash | 2500 并发 | ~无（实际取决于 tier） |
| DeepSeek V4-Pro | 500 并发 | 同上 |
| Anthropic Sonnet 4.6 (Tier 1) | 50 RPM | 40K input TPM |
| Anthropic Opus 4.7 (Tier 1) | 50 RPM | 20K input TPM |

trading-review-wiki 摄入队列是**串行**的，所以个人使用永远不会撞限流。Deep Research 默认 3 并发也安全。

---

## 7. 故障 / 兜底

### DeepSeek 挂了 / 国内访问慢

切到 trading-review-wiki 的 `Anthropic`，临时用 Sonnet 跑摄入。成本会涨 50x 但能继续工作。

### Claude key 被限 / 没卡

降级到 `Custom` + DeepSeek V4-Pro `deepseek-reasoner` 做查询。思考模式输出质量接近 Sonnet 4.6，成本 1/10。

### 完全断网 / 不想付费

`Ollama (Local)` + 本地 70B 模型（如 `qwen3:72b`, `deepseek-r1:70b`）。质量降一档但能离线。需要 64GB+ 内存的机器。

---

## 8. 朋友也想用怎么办

每人自己申请 key。本仓库不会传任何 key —— `.gitignore` 已经拦了 `.env`、`*.key`、`api-keys.json` 等。

朋友看到 wiki 输出觉得不错 → 让他在自己的 trading-review-wiki 里**同样配 DeepSeek 摄入 + Claude 查询**。每个人月成本 $10 上下，可控。

如果想共担成本，可以一起买 [API 中转服务](https://example.com)（自己评估安全/合规）—— 但这超出本仓库的边界，我们不背书。

---

## 9. 演进路径

随着使用：

| 阶段 | 配置变化 |
|---|---|
| 第 1 个月（探索） | DeepSeek Flash 摄入 + Sonnet 4.6 查询，每周复盘成本 |
| 第 3 个月（稳定） | 长文章 / 研报切到 V4-Pro Thinking 提升摘要质量 |
| 第 6 个月（优化） | 开启向量搜索（OpenAI embedding），提升跨题材召回 |
| 长期 | 重要 Deep Research 临时切 Opus 4.7，处理"我搞不清这两个题材到底关系是啥"那种难题 |

每月看一次账单：
- DeepSeek: https://platform.deepseek.com/usage
- Anthropic: https://console.anthropic.com/settings/usage

如果某一项明显超预期，对照表反推："是不是摄入量太大？是不是查询变多了？"

---

参考：
- `templates/purpose.md` — 摄入时 LLM 会读它建立上下文
- `templates/schema.md` — 摄入时 LLM 会读它知道写哪个目录
- `prompts/wiki-ingest-system.md` — 可以直接贴进 trading-review-wiki 的 System Prompt
- `scripts/wiki/setup_wiki.sh` — 初始化一个新的 wiki 工作区
