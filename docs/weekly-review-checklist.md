# 每周复盘 Checklist

> 每周日晚或周一早，花 5-10 分钟跑一遍。**目的不是查问题，是建立"我知道整套系统是活的"的信心**。

## 0. 心态设定

这个 checklist 跑下来大概 5-10 分钟。**不要追求一次跑完所有项**——如果某项卡住超过 2 分钟，标记 TODO 留到下周。

如果连续 2 周某项都失败，那就是真问题，单独排程修。

---

## 1. 数据源健康（2 分钟）

跑：

```bash
# 知识星球
./scripts/zsxq/zsxq_daily.sh --dry-run 2>&1 | tail -5
# 期望：看到"今日: N 条新内容"或"昨日: ..."，不是 401 / cookie 失效

# 微信群
ls -lt ~/wechat-data/cleaned/*/ | head -10
# 期望：每个群最新文件都是 <2 天内的

# IMA 软链
./scripts/ima/ima_link.sh --wiki ~/wiki --check
# 期望：状态: OK (目标可达)，.md 数 > 上周
```

| 检查项 | 状态 | 注意 |
|---|---|---|
| zsxq cookie 还活着 | ☐ | 失效见 `docs/zsxq-cookie-sop.md` 第 3 步 |
| wechat-digest 抓得到 | ☐ | 失败见 `docs/wechat-keys-sop.md`（多半是微信更新了） |
| Obsidian IMA 同步还在拉 | ☐ | Obsidian 设置 → 第三方插件 → ima-copilot Sync → 点"立即同步" |
| 软链都没断 | ☐ | `ls -la ~/wiki/raw/sources/` 看是否有红色 broken |

---

## 2. trading-review-wiki 健康（1 分钟）

打开应用，看：

| 检查项 | 状态 | 注意 |
|---|---|---|
| 活动面板 — 摄入队列没堵 | ☐ | 如果有 >5 个 failed，点 retry；连续失败查 LLM API key 是否过期 |
| 审核面板 — 没堆积 | ☐ | LLM 标记的"需人工判断"项，建议每周清完 |
| 知识图谱 — 没崩 | ☐ | 节点 >3000 会自动归档，看应用是否有提示 |
| Wiki Doctor — 没新警告 | ☐ | 设置 → Wiki Doctor → Scan |

---

## 3. 这周新增内容回顾（2 分钟）

打开 `wiki/log.md`，看顶部最近 7 天：

```bash
# 这周有多少摄入
head -100 ~/wiki/wiki/log.md | grep -c "ingest"
# 例：返回 23，意味着摄入了 23 篇资料
```

或者更直观，在 wiki 里搜索：

```
modified:>2026-05-18 path:wiki/
```

（trading-review-wiki 的搜索框支持 Obsidian 风格 query）

回答自己：

| 问题 | 你的答案 |
|---|---|
| 这周哪个题材内容最多？ | ___ |
| 这周新建了几个股票档案？ | ___ |
| 这周哪个错误页面被更新了？（说明你又踩坑了） | ___ |
| 有没有 sources 数 >5 的"重要页面"出现？（值得 pin 到 index 顶部） | ___ |

---

## 4. 删掉本周噪音（2 分钟）

> 这一步是**主动遗忘**——不重要的资料不要留着拖慢搜索。

打开 trading-review-wiki "资料源" → 按时间排序：

| 候选删除项 | 判断标准 |
|---|---|
| 某篇公众号文章 | 看了一周都没人提及，标题党 → 删 |
| 某个群一周的清洗结果 | 整周都是水群没干货 → 删那个文件，并考虑取消订阅这个群 |
| 某个 wiki/资料/xxx.md | sources 只剩 1 篇且那篇也要删 → 一起删 |

trading-review-wiki 删除时会**级联清理**（README "文件删除级联清理"），所以删了原文，对应 wiki 摘要也会被自动收拾。

> 这一步反直觉：很多人觉得"数据越多越好"。其实**信噪比** = 信号 / (信号 + 噪音)，删噪音和增信号一样重要。

---

## 5. LLM 账单巡查（1 分钟）

| Provider | 看哪里 | 这周费用 | 上周费用 | 异常？ |
|---|---|---|---|---|
| DeepSeek | https://platform.deepseek.com/usage | ___ | ___ | ☐ |
| Anthropic | https://console.anthropic.com/settings/usage | ___ | ___ | ☐ |
| OpenAI (embedding) | https://platform.openai.com/usage | ___ | ___ | ☐ |

预期范围（详见 `docs/llm-provider-routing.md`）：

- DeepSeek: $0.5-3 / 周
- Anthropic: $1-5 / 周（如果跑了 Deep Research，最多 $10）
- OpenAI: $0.05 以下（embedding 极便宜）

**如果某项暴涨 3x**，可能的原因：
- 摄入大批 PDF（一次性把历史研报全导了）→ 一次性，下周回归
- 切错 provider 了（拿 Claude 跑摄入）→ 设置里改回去
- prompt cache 失效（你改了 purpose.md / schema.md）→ 一次性损失，下周自动恢复
- API key 泄漏被人乱用 → 立刻 revoke + 改 key

---

## 6. 反思（5 分钟，最重要的一步）

合上电脑前，问自己：

- 本周 wiki 帮我做出了什么决策？（具体例子）
- 本周 wiki 没帮上忙的场景是什么？为啥？（缺数据？没沉淀？查询方式不对？）
- 下周想优化什么？

写到 `wiki/queries/周复盘-YYYY-MM-DD.md`，让 LLM 摄入这条 meta 反思。

> 这条 meta 数据非常重要——wiki 越用，应该越能反映"你怎么思考"。如果 3 个月后回头看周复盘，发现自己的思维模式有明显演化，说明 wiki 真的在帮你成长。

---

## 7. 月度（每 4 周一次额外加）

```
☐ 备份 ~/wiki 整个目录到外置硬盘 / NAS
☐ 备份 ~/.wechat-digest/all_keys.json 到 1Password 等密码管理器
☐ 检查 `docs/architecture.md` 和实际架构是否还匹配，不匹配就更新文档
☐ 跑一次 trading-review-wiki 的 Wiki Doctor（设置 → Wiki Doctor → Scan + 自动备份）
☐ 看 trading-review-wiki 有没有新版本，看 CHANGELOG，决定升级
☐ 看 toolkit 仓库有没有新版本：cd ~/code/trading-research-toolkit && git pull
```

---

## 模板：把 checklist 拷贝到你的 wiki

> 每周新建一个文件，跑完留痕。

```bash
mkdir -p ~/wiki/wiki/queries/周复盘
cat > ~/wiki/wiki/queries/周复盘/$(date +%F)-周复盘.md <<'EOF'
---
type: weekly_review
title: 周复盘-YYYY-MM-DD
date: YYYY-MM-DD
---

# 数据源健康
- zsxq cookie: ✅ / ❌（备注：）
- wechat-digest: ✅ / ❌
- IMA 同步: ✅ / ❌
- 软链: ✅ / ❌

# wiki 应用
- 摄入队列: 通畅 / 堵了 N 个
- 审核: 0 个待办 / N 个待办
- 图谱: 正常 / 异常

# 本周回顾
- 新增题材热点：
- 新建股票档案：
- 更新错误页面：
- 重要资料（sources>5）：

# 删除清单
- 

# LLM 账单
- DeepSeek: $___（上周 $___，变化 +/-）
- Anthropic: $___
- 异常：

# 反思
- 本周 wiki 帮我做的决策：
- wiki 没帮上忙的场景：
- 下周优化：
EOF
```

跑了几周后，回头看自己的周复盘，能直观感受系统是否在"自我强化"。
