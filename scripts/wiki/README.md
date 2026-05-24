# scripts/wiki — wiki 工作区初始化

> 一条命令把一个空目录变成 trading-review-wiki 能立刻用的工作区，并把已经跑通的 4 个上游数据源（IMA 公众号 / 知识星球 / 微信群 / 研报 PDF）全部链好。

## 文件清单

| 文件 | 作用 |
|---|---|
| `setup_wiki.sh` | 初始化 + 软链一条龙 |
| `README.md` | 本文 |

## 快速上手

### 最小化（只建结构和模板）

```bash
./scripts/wiki/setup_wiki.sh ~/wiki
```

会得到：

```
~/wiki/
├── purpose.md                  ← 复制自 toolkit/templates/
├── schema.md                   ← 复制自 toolkit/templates/
├── raw/
│   ├── sources/                ← (空，待你放数据)
│   ├── assets/
│   └── 日复盘/                  ← trading-review-wiki 自动写
├── wiki/
│   ├── index.md                ← 空骨架，摄入后自动补
│   ├── log.md                  ← 已写第一条 init
│   ├── overview.md             ← 空骨架，摄入后自动重写
│   ├── 股票/, 题材/, 板块/, 模式/, 错误/, 人物/, 事件/, 综合/, 资料/, queries/
├── .obsidian/app.json          ← Obsidian 兼容配置
└── .llm-wiki/chats/            ← trading-review-wiki 用
```

打开 trading-review-wiki → 创建项目 → 选这个目录就能用。

### 完整（一并链 4 个数据源）

> 假设你已经分别跑通了 IMA / 知识星球 / 微信群 / 研报 PDF 的同步。

```bash
./scripts/wiki/setup_wiki.sh ~/wiki \
  --ima-vault    ~/ObsidianVault/A股研究 \
  --zsxq-dir     ~/zsxq-data \
  --wechat-dir   ~/wechat-data/cleaned \
  --research-dir ~/research-pdfs
```

会在 `~/wiki/raw/sources/` 下创建：

```
wechat-mp  → ~/ObsidianVault/A股研究/IMA               (公众号文章)
zsxq       → ~/zsxq-data                              (知识星球)
wechat     → ~/wechat-data/cleaned                    (微信群清洗后)
research   → ~/research-pdfs                          (研报 PDF)
```

trading-review-wiki 启动后会扫描 `raw/sources/` 自动启动摄入队列。

### 其它选项

```bash
./setup_wiki.sh ~/wiki --dry-run              # 只打印，不动文件
./setup_wiki.sh ~/wiki --force-templates      # 覆盖已有的 purpose.md / schema.md
./setup_wiki.sh ~/wiki --webclip-dir ~/webclip # 也支持 trading-review-wiki Chrome 扩展的输出目录
```

## 设计原则

### 幂等

重跑 `setup_wiki.sh` 对已存在的文件/目录**不会破坏**：
- 已有的 `purpose.md` / `schema.md` 保留（除非 `--force-templates`）
- 已有的 `index.md` / `log.md` / `overview.md` 保留
- 已有的软链如果指向不同位置会**替换**；如果指向相同位置**保持不变**
- 普通目录（不是 symlink）**永远不会被删除**

### 软链而非拷贝

数据源用软链 + 集中维护是核心设计：
- 上游数据更新（IMA 拉到新文章、wechat_daily.sh 出新清洗文件）→ wiki 立刻看到
- 不占额外磁盘
- 删除 wiki 不会丢原始数据（链断了不会删源）
- 数据源换路径 → 重跑一次 setup_wiki 就好

### 跟 toolkit 仓库解耦

`purpose.md` / `schema.md` 是**拷贝**进 wiki 的，不是软链。理由：
- 你会根据自己的研究偏好调整 purpose（行业兴趣、风格主张），不应该被 toolkit 升级覆盖
- toolkit 升级时如果你想 pull 最新模板，跑 `--force-templates`，手动 diff
- `templates/` 在 toolkit 里持续演进，作为"出厂默认值"

### 跟 Obsidian 共用

`.obsidian/app.json` 让这个目录同时也是合法的 Obsidian vault：
- 你可以 Obsidian 打开 `~/wiki` 看 wiki/ 下的所有页面
- `[[wikilink]]` 跳转正常工作
- trading-review-wiki 不会跟 Obsidian 冲突（一个写 raw/wiki，一个只读 / 编辑 wiki）

## 跟其它 toolkit 脚本的关系

```
                 ┌──── scripts/zsxq/zsxq_daily.sh ────► ~/zsxq-data/
                 │
                 ├──── scripts/wechat/wechat_daily.sh ─► ~/wechat-data/cleaned/
 上游数据脚本    │
                 ├──── scripts/ima/ima_link.sh ───────► ~/ObsidianVault/A股研究/IMA/
                 │
                 └──── (手动复制 PDF) ─────────────────► ~/research-pdfs/
                                  │
                                  ▼
                       scripts/wiki/setup_wiki.sh
                       一次性把 4 个软链建好
                                  │
                                  ▼
                          ~/wiki/raw/sources/
                                  │
                                  ▼
                       trading-review-wiki 摄入
```

## 故障排查

### "找不到 templates/purpose.md"

`setup_wiki.sh` 在自己的同级 `../../templates/` 找模板。如果你**拷贝**了脚本到别处单独使用，会找不到。两个解决：

1. clone 整个 `trading-research-toolkit` 跑（推荐）
2. 设环境变量 `TOOLKIT_ROOT=/path/to/toolkit`（脚本暂时未支持，要加的话改 `SCRIPT_DIR` 那段）

### 已经有 wiki 但想换 toolkit 模板

```bash
# 备份现有的
cp ~/wiki/purpose.md ~/wiki/purpose.md.bak.$(date +%F)
cp ~/wiki/schema.md ~/wiki/schema.md.bak.$(date +%F)

# 强制更新
./setup_wiki.sh ~/wiki --force-templates

# diff 看变化，挑你想要的合回去
diff ~/wiki/purpose.md.bak.* ~/wiki/purpose.md
```

### 想把 wiki 搬家

```bash
# 1. 关掉 trading-review-wiki
# 2. 移动目录
mv ~/wiki ~/Documents/wiki

# 3. 重新跑 setup_wiki（会保留所有内容，只是把软链更新到新路径）
./setup_wiki.sh ~/Documents/wiki \
  --ima-vault    ~/ObsidianVault/A股研究 \
  --zsxq-dir     ~/zsxq-data \
  ...

# 4. trading-review-wiki 里打开 ~/Documents/wiki 作为项目
```

### 想分享 wiki 给朋友

**不要直接打包整个目录**！里面有 `raw/sources/wechat/` (你的微信群聊天) 和 `raw/sources/zsxq/` (你付费的星球内容)，都是高度敏感/有版权的。

正确做法：
- 只分享 toolkit 仓库（脚本 + 模板 + 文档）
- 朋友自己跑 `setup_wiki.sh` + 自己的数据源
- 如果想分享研究结论，分享单独的 `wiki/股票/xxx.md` 等 markdown 片段（已经经过 LLM 提炼，不含敏感原文）
- 详见 `docs/friend-onboarding.md`
