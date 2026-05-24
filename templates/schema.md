---
title: A 股研究 wiki 的结构规则
version: 1.0
---

# Schema

> 本文件定义 wiki 的"骨架"：有哪些页面类型、各自的 frontmatter、各自的命名和目录约定。
> LLM 在生成或更新页面时必须严格遵守。

---

## 三层架构

```
~/wiki/
├── purpose.md                  ← Wiki 的目的（不可变，人工维护）
├── schema.md                   ← 本文件
├── raw/                        ← 原始资料（不可变）
│   └── sources/
│       ├── wechat-mp/          ← 公众号文章（IMA 同步）
│       ├── zsxq/               ← 知识星球（脚本同步）
│       ├── wechat/{群名}/      ← 微信群清洗后的聊天
│       ├── research/           ← 历史研报 PDF
│       └── 日复盘/             ← trading-review-wiki 自动生成
└── wiki/                       ← LLM 生成（可被 LLM 重写）
    ├── index.md                ← 目录
    ├── log.md                  ← 操作日志
    ├── overview.md             ← 全局概要（自动更新）
    ├── 股票/                   ← 个股档案
    ├── 题材/                   ← 题材分析
    ├── 板块/                   ← 行业板块
    ├── 模式/                   ← 交易模式（龙头、龙回头、低吸等）
    ├── 错误/                   ← 错误案例和教训
    ├── 人物/                   ← 重要观点提出者（券商分析师、大 V）
    ├── 事件/                   ← 重要事件（政策、并购、业绩超预期等）
    ├── 综合/                   ← 跨题材分析、综述
    └── queries/                ← 保存的聊天回答
```

---

## 页面类型

每个类型有固定的 frontmatter 字段和目录归属。

### 1. 股票（`wiki/股票/`）

```yaml
---
type: stock
title: 中际旭创
code: 300308
exchanges: [SZ]
industries: [通信设备, 光模块, 算力]
themes: [AI算力, CPO, 800G光模块]
sources: [wechat-mp/2026-05-15-某号文章.md, zsxq/123456.md]
status: active   # active | suspended | delisted
last_updated: 2026-05-24
---
```

**正文结构**（建议）：
- ## 公司概况
- ## 核心业务
- ## 题材归属
- ## 关键观点（按时间倒序，每条标注来源）
- ## 交易记录（可选，链接到日复盘）
- ## 相关公司（`[[wikilink]]`）

### 2. 题材（`wiki/题材/`）

```yaml
---
type: theme
title: AI 算力
related_themes: [CPO, 液冷, 服务器, 光模块]
related_stocks: [中际旭创, 工业富联, 浪潮信息]
lifecycle: 分化  # 萌芽 | 爆发 | 分化 | 退潮
sources: [...]
last_updated: 2026-05-24
---
```

**正文结构**：
- ## 题材逻辑
- ## 龙头与跟风
- ## 演变脉络（按时间）
- ## 当前阶段判断
- ## 风险因素

### 3. 板块（`wiki/板块/`）

```yaml
---
type: sector
title: 半导体
sub_sectors: [设计, 制造, 设备, 材料]
related_themes: [自主可控, AI算力, 存储]
sources: [...]
---
```

### 4. 模式（`wiki/模式/`）

```yaml
---
type: pattern
title: 龙回头
category: 趋势策略
success_cases: [案例-中际旭创-202404, 案例-某股-202405]
failure_cases: [案例-某股-202403]
sources: [...]
---
```

**正文结构**：
- ## 定义
- ## 适用条件
- ## 成功案例
- ## 失败案例
- ## 关键信号
- ## 仓位建议

### 5. 错误（`wiki/错误/`）

```yaml
---
type: mistake
title: 追高被套-某股-202405
related_stocks: [某股]
related_patterns: [追涨]
date: 2026-05-15
loss_pct: -8.5
lesson: 情绪退潮期不应追龙头补涨股
sources: [...]
---
```

### 6. 人物（`wiki/人物/`）

```yaml
---
type: person
title: 某分析师
role: 券商分析师  # 券商分析师 | 大V | 群友 | 自媒体
affiliation: XX证券
specialties: [半导体, AI算力]
sources: [...]
track_record: 8/12  # 8 次预测对中 12 次（可选，长期填）
---
```

### 7. 事件（`wiki/事件/`）

```yaml
---
type: event
title: 算力新基建政策-202405
date: 2026-05-10
category: 政策催化  # 政策 | 业绩 | 并购 | 突发 | 海外联动
impact_stocks: [中际旭创, 浪潮信息]
impact_themes: [AI算力]
verified_outcome: 涨 18% 持续 3 周
sources: [...]
---
```

### 8. 综合 / 综述（`wiki/综合/`）

```yaml
---
type: synthesis
title: AI 算力 vs 半导体周期-202405 对比
related_themes: [AI算力, 半导体周期]
related_stocks: [...]
sources: [...]
---
```

跨题材的对比分析、研究综述。

### 9. 资料摘要（`wiki/资料/`）

每条 `raw/sources/` 进来后，LLM 必须生成对应的摘要页：

```yaml
---
type: source_summary
title: 某号-AI算力研报-2026-05-15
source_file: raw/sources/wechat-mp/2026-05-15-xxx.md
source_type: wechat-mp  # wechat-mp | zsxq | wechat-group | research | webclip
author: 某分析师
date: 2026-05-15
related_stocks: [...]
related_themes: [...]
key_claims: [...]
---
```

---

## 命名规则

| 类型 | 文件名格式 | 例 |
|------|----------|-----|
| 股票 | `{中文全称}.md` | `中际旭创.md` |
| 题材 | `{题材名}.md` | `AI算力.md` |
| 板块 | `{板块名}.md` | `半导体.md` |
| 模式 | `{模式名}.md` | `龙回头.md` |
| 错误 | `{简述}-{股票}-{YYYYMM}.md` | `追高被套-中际旭创-202405.md` |
| 人物 | `{昵称}.md` | `某分析师.md` |
| 事件 | `{事件名}-{YYYYMM}.md` | `算力新政-202405.md` |
| 资料摘要 | `{来源}-{标题简述}-{日期}.md` | `某号-AI算力研报-20260515.md` |

---

## 交叉引用

- 全部用 `[[wikilink]]` 语法，不要用 markdown 链接
- 链接默认指向同名页面：`[[中际旭创]]`
- 跨类型链接：`[[股票/中际旭创]]`、`[[题材/AI算力]]`
- 不存在的页面也可以先链上，作为"待补充"信号

---

## 增量摄入约定

LLM 摄入新资料时：

1. 如果引入了**新股票/新题材/新人物**，必须创建对应页面（不能只在某篇内容里提一下）
2. 如果**修改了已有页面**，必须在该页面的 `## 关键观点` 末尾追加新条目（不是覆盖）
3. 如果发现**矛盾**，必须在被矛盾的页面里加 `## 矛盾观点` 章节
4. 永远不要删除其他来源的引用（`sources[]` 数组只增不减，除非源文件被显式删除）

---

## 不允许的事

- ❌ 创建英文目录（`entities/` / `concepts/`）— 全用中文
- ❌ 在 `wiki/` 下放原始资料 — 原文只能在 `raw/`
- ❌ 跨过 `index.md` 直接维护 — 所有页面创建/重命名都要更新 index
- ❌ 在股票页面写"建议买入"或"目标价" — 只记录观点和事实，不出投资建议
