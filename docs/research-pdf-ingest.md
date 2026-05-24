# 研报 PDF 批量入库

> 你手里可能有过去几年攒下的几百份券商研报 PDF。这篇讲怎么把它们一次性进 wiki，且避免 LLM 账单爆炸。

## 整体策略

1. **整理命名**——批量重命名成 `YYYY-MM-DD-机构-标题.pdf`
2. **放进目录**——`~/research-pdfs/{年份}/{行业}/`
3. **软链入库**——`setup_wiki.sh --research-dir ~/research-pdfs` 已经帮你建好软链
4. **切到便宜的 provider**——摄入用 DeepSeek V4-Pro Thinking（长文档需要思考能力，但 V4-Pro 仍只是 Claude 1/5 价）
5. **分批摄入**——一次 20 份，看摄入质量再决定是否继续

---

## 步骤 1：收集所有 PDF

常见来源：

| 来源 | 怎么拿 |
|---|---|
| 卖方研报订阅邮箱 | `~/Downloads` 里通常一堆 |
| 公司年报 | 巨潮资讯 / 公司官网下载 |
| 同事 / 群友分享 | 微信文件 → 保存到 Mac |
| 历史 Pocket / Cubox | export 出来 |

集中放到 `~/research-pdfs-raw/` 里（不分目录，先堆一起）。

## 步骤 2：批量重命名

理想文件名：`YYYY-MM-DD-机构简称-标题.pdf`

例子：

```
2026-04-12-华泰证券-AI算力深度报告.pdf
2026-04-15-招商证券-中际旭创首次覆盖.pdf
2026-05-02-国信证券-光模块行业月报.pdf
```

为什么这样：
- 日期前缀 → 时间排序自然
- 机构名 → wiki 里能自动归类到 `wiki/人物/{机构}` 或作为 `source` 字段
- 简短标题 → LLM 摄入时用作初始上下文

### 怎么改？

如果文件名已经规范，跳过。如果是各种乱七八糟的（如 `2026年4月行业月报-final-v2.pdf`），有几个办法：

#### 选项 A：手动改（推荐 < 50 份的场景）

边过一遍边改，5 秒一份。这也是粗筛：明显凑数的报告直接扔。

#### 选项 B：写个 Python 脚本批量改

```python
# 假设文件名包含日期但格式不一致
import re, os
from pathlib import Path

DIR = Path("~/research-pdfs-raw").expanduser()

DATE_PATTERNS = [
    r"(20\d{2})[-_年](\d{1,2})[-_月](\d{1,2})",
    r"(20\d{2})(\d{2})(\d{2})",
]
INSTITUTIONS = {
    "华泰": "华泰证券", "中信": "中信证券",
    "招商": "招商证券", "国信": "国信证券",
    # ...
}

for f in DIR.glob("*.pdf"):
    name = f.stem
    # 1. 抽日期
    date = "0000-00-00"
    for pat in DATE_PATTERNS:
        m = re.search(pat, name)
        if m:
            y, mo, d = m.groups()
            date = f"{y}-{int(mo):02d}-{int(d):02d}"
            break

    # 2. 抽机构
    inst = "未知机构"
    for k, v in INSTITUTIONS.items():
        if k in name:
            inst = v
            break

    # 3. 标题：去日期 + 去机构 + 清理
    title = re.sub(r"[0-9]+[-_/年月日]?", "", name)
    title = title.replace(inst, "").strip(" -_·")
    title = re.sub(r"\s+", "", title)[:30]

    new_name = f"{date}-{inst}-{title}.pdf"
    new_path = f.parent / new_name
    if new_path != f and not new_path.exists():
        f.rename(new_path)
        print(f"{f.name} → {new_name}")
```

跑完手动检查一遍，发现"未知机构 / 0000-00-00"的手动改。

#### 选项 C：让 LLM 帮你改

最高级：每个 PDF 头几页给 Claude / DeepSeek 看，让它返回标准化名字。但这一步要花钱（每份 PDF 约 $0.05 Claude / $0.001 DeepSeek 加上 PDF OCR 成本）。对 < 100 份的场景**不划算**，不如手动。

## 步骤 3：分目录归档

```
~/research-pdfs/
├── 2026/
│   ├── 半导体/
│   │   ├── 2026-04-12-华泰证券-AI算力深度报告.pdf
│   │   └── 2026-05-02-国信证券-光模块行业月报.pdf
│   ├── 新能源/
│   └── 综合/
├── 2025/
│   └── ...
└── 历史/                # 2025 年前的，反正不会经常翻
```

trading-review-wiki 的"文件夹导入"功能会把**目录路径作为 LLM 摄入的上下文**——README 提到："文件夹路径作为 LLM 分类上下文（如 `papers > energy` 帮助分类）"。

所以 `2026/半导体/xxx.pdf` 这种结构会让 LLM 知道这是一篇"2026 年 / 半导体类"的研报，分类质量更高。

> 注意：分类不必很细。"半导体 / 新能源 / 综合 / 宏观" 4-5 个粗类就行。LLM 摄入后会自动建更细的 `wiki/题材/` 页面。

## 步骤 4：软链入 wiki

之前如果跑 `setup_wiki.sh --research-dir ~/research-pdfs` 已经建过软链，跳过这一步。

如果没建：

```bash
ln -s ~/research-pdfs ~/wiki/raw/sources/research
```

或重跑：

```bash
./scripts/wiki/setup_wiki.sh ~/wiki --research-dir ~/research-pdfs
```

## 步骤 5：切到合适的 LLM provider

> 关键决策：用什么 LLM 摄入 PDF。

| 选项 | 价格 (单份 50 页研报) | 质量 | 建议 |
|---|---:|---|---|
| Claude Opus 4.7 | ~$0.50 | 最好 | 太贵；100 份就 $50 |
| Claude Sonnet 4.6 | ~$0.10 | 很好 | 200 份就 $20，可接受但不必要 |
| **DeepSeek V4-Pro Thinking** | ~$0.01 | 好 | **推荐**：100 份只要 $1，摄入研报够用 |
| DeepSeek V4-Flash | ~$0.003 | 中等 | 太省思考能力，长 PDF 容易丢线索 |

设置 trading-review-wiki：
- 提供商：`Custom`
- Endpoint: `https://api.deepseek.com/v1`
- Model: `deepseek-reasoner`（= V4-Pro thinking）
- Max Context: `131072`（128K）—— PDF 提取后基本不会超

详见 `docs/llm-provider-routing.md`。

## 步骤 6：摄入

### 方案 A：一次性全摄入（适合 < 50 份）

打开 trading-review-wiki → 资料源 → 点 `~/wiki/raw/sources/research` 软链对应的目录 → 应该看到 trading-review-wiki 自动扫描出所有 PDF → 队列开始处理。

PDF 摄入比 markdown 慢：每份大约 1-5 分钟（含 OCR + LLM 两步思维链）。50 份 ≈ 1-4 小时。

### 方案 B：分批摄入（适合 > 100 份）

不要一次性。理由：
- 一次性炸队列容易遇到 LLM API rate limit
- 摄入完一批后**先看 wiki 质量**，质量差就调 prompt（`wiki-ingest-system.md`），不要错的方向继续跑
- 一次性烧 $5-10 心疼，分批每天 20 份感知更平滑

策略：
```bash
# 把 200 份的目录拆成 10 个 20 份的子目录
mkdir -p ~/research-pdfs/批次{01..10}

# 把文件均分进去（用你喜欢的方式：按日期、按行业、按字母）
# ...

# 每天软链一个子目录到 wiki，trading-review-wiki 摄入完再切下一批
rm ~/wiki/raw/sources/research-current
ln -s ~/research-pdfs/批次01 ~/wiki/raw/sources/research-current

# 第二天
rm ~/wiki/raw/sources/research-current
ln -s ~/research-pdfs/批次02 ~/wiki/raw/sources/research-current
```

> 进阶：写个 cron，每天凌晨 03:00 自动 rotate。但 200 份历史 PDF 是**一次性导入**，不值得为它写自动化。

## 步骤 7：检查摄入质量

摄入完一批后，去看：

| 检查 | 看哪里 | 期望 |
|---|---|---|
| 资料摘要页都生成了 | `wiki/资料/` | 跟 PDF 数差不多（少几个是正常的，超长 PDF 可能跳过） |
| 股票档案有更新 | `wiki/股票/中际旭创.md` 看 sources[] 数 | 这批研报涉及的股票，sources 都有增长 |
| 题材页有更新 | `wiki/题材/AI算力.md` 看"演变脉络"章节 | LLM 应该把新观点追加进去 |
| 没有重复 / 矛盾 | 知识图谱 → 找重复节点 | wiki Doctor 跑一下，提示有问题手动合并 |

如果 LLM 摄入质量差（如 `wiki/资料/xxx.md` 都是占位空内容），说明：
- PDF 提取出问题 → 这本身是 PDF 复杂度问题（图表多、扫描件等），下游 LLM 无能为力
- 或 prompt 没设定好 → 调 `prompts/wiki-ingest-system.md`

## 维护：日常增量

历史 PDF 导入是一次性大活，未来增量很轻：

- 新订阅一份券商日报？拖进 `~/research-pdfs/2026/{分类}/` → wiki 自动摄入
- 每月汇总：跑下面 cmd 看本月新增

```bash
find ~/research-pdfs -name '*.pdf' -newermt "$(date +%Y-%m)-01" | wc -l
```

## 故障排查

### 摄入失败：`PARSE_ERROR PDF 解析失败`

PDF 可能是扫描件（图片）或加密。trading-review-wiki 用 `pdf-extract`（Rust 后端）做提取，遇到扫描件无效。

**解决**：
1. 用 macOS Preview → 文件 → 导出为 PDF（如果已经是 PDF 这一步会重新光栅化但解决加密）
2. 跑 OCR：`brew install ocrmypdf && ocrmypdf input.pdf output.pdf`，然后重新放入

### 摄入失败：`文件过大`

`CLAUDE.md` 性能红线：PDF > 100MB 拒绝读取。

**解决**：拆 PDF（macOS Preview 选页 → 导出选中页）。或者这种过大 PDF 一般是图册，不值得入库。

### LLM 摄入慢

长 PDF + Thinking 模型一份要 3-5 分钟。**正常**，让它慢慢跑就好。

如果**真**要快：临时切回 V4-Flash 非思考模式，速度 2-3x，质量会降一档（章节归类没那么准）。

### 摄入完发现 wiki 充满"未分类" / "待补充"

`purpose.md` 没读到位。检查：
1. trading-review-wiki 是否在第一步分析时读了 purpose.md（在活动面板看 LLM 调用日志）
2. `purpose.md` 是不是太抽象（"我研究 A 股"这种没用）—— 改成具体研究方向（"关注 AI 算力 + 半导体周期 + 龙头战法"）

详见 `templates/purpose.md` 的示例。

---

参考：
- `docs/llm-provider-routing.md` — DeepSeek V4-Pro 配法
- `scripts/wiki/setup_wiki.sh` — `--research-dir` 软链建立
- `templates/schema.md` — `research` 类型的 frontmatter 字段
- `prompts/wiki-ingest-system.md` — 如果摄入质量不满意要调这里
