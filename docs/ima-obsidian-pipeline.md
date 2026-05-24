# 公众号 → IMA → Obsidian → wiki 完整 SOP

> 把公众号文章自动落到 `trading-review-wiki` 的 raw 目录，全程不写爬虫，不踩公众号反爬，且能复用 IMA 的 OCR、跨设备多端同步、AI 摘要等能力。

## 0. 为什么用这条链路

| 候选方案 | 问题 |
|---|---|
| 自己写公众号爬虫 | 反爬严重 / 链接 24h 过期 / 维护成本高 |
| 复制粘贴到 Markdown | 手工活，没人会坚持 |
| 用第三方剪藏（如 Cubox） | 微信里"复制链接 → 切回剪藏 app"步骤多 |
| **IMA + Obsidian sync** | **微信原生分享菜单直接出现 IMA 选项，3 秒一篇；后台同步到本地** |

腾讯 IMA 还有两个附加好处：

1. **公众号原文样式保留**（图片、表格、公式都完整），不像剪藏只剩纯文字
2. **iOS / macOS / Windows 多端同步**——手机上看到好文章一键存，回到 Mac 已经在 vault 里了

链路全图：

```
微信公众号文章
   │ 右上角 · · ·
   │ → "分享到"
   │ → "IMA"
   ▼
IMA 云端知识库
   │ Obsidian "ima.copilot Sync" 插件
   │ （定时拉，默认 5 min）
   ▼
Obsidian Vault
   $OBSIDIAN_VAULT/IMA/
   ├── 2026-05-24-某号-AI算力研报.md
   └── attachments/...
   │ scripts/ima/ima_link.sh
   │ （建一次软链，永久生效）
   ▼
trading-review-wiki
   $WIKI/raw/sources/wechat-mp/  → $OBSIDIAN_VAULT/IMA/  (软链)
   │ 应用启动时自动扫描 raw/sources/
   ▼
LLM 两步摄入 → wiki/资料/ + wiki/股票/ + wiki/题材/ + ...
```

---

## 1. 装 IMA

### 1.1 移动端

- iOS: App Store 搜 `腾讯 ima`
- Android: 各大应用市场或 https://ima.qq.com 下载

用微信账号登录。建议**开启 iCloud / 厂商云同步**保证不丢数据。

### 1.2 桌面端（必装）

打开 https://ima.qq.com，下载 macOS / Windows 客户端，登录同一微信账号。

> 桌面端是 Obsidian sync 的依赖：插件读 IMA 的本地数据库。**没装桌面端的话 sync 插件抓不到东西**。

### 1.3 建一个研究专用知识库

IMA 里"知识库"概念 = 一个独立的存储桶。建议建一个独立的：

- 名字：`A股研究` 或 `投研`
- 默认知识库切换到这个
- 之后转发文章会进这个库

---

## 2. 微信里转发公众号文章到 IMA

每次看到值得收的公众号文章：

1. 文章右上角 `···`
2. `分享到` → 找 **IMA**（图标是橙红色"i")
3. 选目标知识库 = `A股研究`
4. 可选：加标签 / 改标题

> 第一次用要给微信"允许跳转到 IMA"权限。

**手机和电脑通用同一个微信号 → 文章同步到云端 → 任何设备都能看到。**

### 高频技巧

- **iOS Shortcuts**：建个快捷指令"分享到 IMA 默认库 A股研究"，进一步减少点击
- **PC 微信**：右键文章链接也有"分享到 IMA"
- **批量回收**：以前没整理的旧文章，可以从微信收藏直接转

---

## 3. 装 Obsidian + `ima.copilot Sync` 插件

### 3.1 装 Obsidian

https://obsidian.md 下载。建议 vault 路径放在**本地磁盘**（不要 iCloud / Dropbox 同步——后面要软链给 wiki，云盘有路径解析陷阱）。

例：

```
~/ObsidianVault/A股研究/
```

### 3.2 装 `ima.copilot Sync` 插件

> 这是 IMA 官方的 Obsidian 插件。

1. Obsidian → 设置 → 第三方插件 → 关闭"安全模式"
2. 浏览社区插件 → 搜 `ima.copilot Sync` → 安装 → 启用
3. 打开插件设置：
   - **知识库**：选你刚才在 IMA 里建的 `A股研究`
   - **同步目录**：填 `IMA`（Obsidian vault 内的相对路径）
   - **同步频率**：5 分钟（默认）或调成 1 分钟
   - **附件存储**：相对 `IMA/attachments`
   - **同步策略**：增量（默认）
4. 点 `立即同步` 验证 → 看到 Obsidian 左边 `IMA/` 目录出现文章

> 如果找不到插件，IMA 官网 / GitHub 有 manual install 包：
> https://ima.qq.com/document/help.html 找 "Obsidian"

### 3.3 同步产物形态

每个文章一个 markdown 文件，文件名形如：

```
IMA/
├── 2026-05-24-中际旭创二季度业绩超预期-某号.md
├── 2026-05-24-AI算力深度报告-某券商.md
├── attachments/
│   ├── 2026-05-24-xxx-img1.png
│   └── ...
```

文件内 frontmatter 大致：

```yaml
---
title: 中际旭创二季度业绩超预期
source: 某公众号
url: https://mp.weixin.qq.com/s/abc...
clipped_at: 2026-05-24T09:31:42+08:00
ima_doc_id: doc_abc123
tags: [AI算力, 光模块]
---
```

> 不同版本的 IMA 插件 frontmatter 字段会变。后面 `normalize_ima.py` 会把它统一成 trading-review-wiki 期望的形态。

---

## 4. 接入 trading-review-wiki

### 4.1 软链（一次性）

```bash
# 假设：
#   OBSIDIAN_VAULT = ~/ObsidianVault/A股研究
#   WIKI           = ~/wiki

mkdir -p ~/wiki/raw/sources
ln -s ~/ObsidianVault/A股研究/IMA ~/wiki/raw/sources/wechat-mp
```

或者用我们准备好的 `scripts/ima/ima_link.sh`：

```bash
./scripts/ima/ima_link.sh \
  --vault ~/ObsidianVault/A股研究 \
  --wiki  ~/wiki
```

软链做了之后：

- Obsidian sync 拉到新文章 → 直接落到 `~/ObsidianVault/A股研究/IMA/xxx.md`
- 同一个文件在 `~/wiki/raw/sources/wechat-mp/xxx.md` 也能看到（软链穿透）
- trading-review-wiki 启动后会自动 scan 这个目录，新文件触发摄入

> macOS Finder / Tauri 都正确支持 symlink，不需要特殊配置。

### 4.2 (可选) frontmatter 规范化

如果 IMA 的 frontmatter 字段名跟我们 `templates/schema.md` 期望的不一致，可以跑：

```bash
./scripts/ima/normalize_ima.py ~/ObsidianVault/A股研究/IMA
```

会就地把 frontmatter 改成：

```yaml
---
type: raw_source
source_type: wechat-mp
title: ...
source: ...
url: ...
clipped_at: 2026-05-24
---
```

幂等：跑过的文件下次跳过（看 frontmatter 里有没有 `normalized: true`）。

### 4.3 触发摄入

打开 trading-review-wiki，进入项目（项目路径 = `~/wiki`）：

- **活动面板**会显示有新文件待摄入
- 也可以手动 `资料源` 标签 → 点新文件 → 右上角 `Ingest`
- 摄入完成后，wiki 目录会出现 `资料/某号-AI算力研报-20260524.md`、`股票/中际旭创.md` 等

---

## 5. 日常工作流（一图流）

```
通勤刷公众号
    │ 看到好文章
    ▼
点右上角 · · · → 分享 → IMA
    │
    ▼  （5 分钟内）
Obsidian 左边 IMA/ 目录出现新 md
    │
    ▼  （Mac 上打开 trading-review-wiki）
活动面板提示"3 个新文件待摄入"
    │
    ▼  （后台 LLM 跑 1-3 分钟）
wiki/股票/中际旭创.md 出现新观点（带来源链接回 wechat-mp/）
wiki/题材/AI算力.md 演变脉络补一条
wiki/资料/某号-xxx.md 摘要页
```

整个过程**没有任何爬虫**，没有 cookie 失效问题，没有反爬。代价是要登录微信生态，但你本来就要看公众号。

---

## 6. 常见问题

**Q1: IMA 是云端的，我的数据安全吗？**
A: 公众号文章本来就是公开内容；IMA 同步的是文章 + 你的 tag/笔记。如果你担心，可以：
- 不要在 IMA 里写敏感笔记（写在 Obsidian 本地）
- 转发只发公众号文章，不发交易明细 / 持仓截图

**Q2: IMA 桌面端必须一直开着吗？**
A: 不开着也能在手机上转发；同步到 Obsidian 必须**桌面端开着 + Obsidian 开着 + sync 插件启用**。建议把 IMA 桌面端设成开机自启动 + 后台运行。

**Q3: 朋友能共享我的 IMA 知识库吗？**
A: IMA 支持"共享知识库"——你可以建一个团队库，朋友看你存的文章。但**他们的 Obsidian 同步是各自的**，sync 插件按账号拉。

**Q4: 一天转 50 篇文章，wiki 会不会被 LLM 摄入卡死？**
A: trading-review-wiki 的摄入队列是**串行 + 持久化 + 自动重试**，不会丢任务。但你 LLM API 账单会涨。建议：
- 配置 `深度摄入用 Claude / 浅层摄入用 DeepSeek`（见 `docs/llm-provider-routing.md`）
- 一天最多转 10-15 篇精品，宁缺毋滥

**Q5: 同一篇文章重复转发会怎样？**
A: IMA 自身去重（按 URL）；Obsidian sync 不会重复创建文件；trading-review-wiki 用 SHA256 内容哈希增量缓存，**内容没变就跳过 LLM 调用**——零成本。

**Q6: 我已经存在 Cubox / Notion / Pocket 里的旧文章呢？**
A: 两种思路：
- 一次性导出 Markdown，放到 `~/wiki/raw/sources/legacy/` 让 trading-review-wiki 批量摄入
- 重要的几篇手动重新发到 IMA，享受统一管理

**Q7: 不想用 IMA / IMA 不可用怎么办？**
A: 备选剪藏：
- Obsidian 自带 Web Clipper（Chrome 插件）—— 在电脑上打开公众号 PC 版剪藏
- trading-review-wiki 自带的 Chrome 扩展（见 README "网页剪藏"）—— 直接落到 `raw/sources/webclip/`
- 微信小程序 "墨问便签" 等本地化剪藏方案

但 IMA 是目前**移动端转发体验最好的**。

---

## 7. 给朋友（同样要建库）的最小副本

如果朋友要复制这套流程：

1. 微信 + IMA 装好，登录他自己的微信
2. 自己建一个 IMA 知识库（名字随意）
3. 装 Obsidian + ima.copilot Sync 插件，配自己的 vault
4. clone 这个 `trading-research-toolkit`，跑 `scripts/wiki/setup_wiki.sh` 初始化他自己的 wiki
5. 跑 `scripts/ima/ima_link.sh` 把他的 Obsidian IMA 目录链到他的 wiki
6. trading-review-wiki 装好，打开他自己的 wiki 项目

每个人的 IMA + 微信 + wiki **完全独立**。共享的是：本仓库的脚本 + purpose.md / schema.md 模板 + （可选）IMA 团队知识库（如果你们想合作收文章）。

---

参考：
- `scripts/ima/README.md` — 脚本目录索引
- `scripts/ima/normalize_ima.py` — frontmatter 规范化
- `scripts/ima/ima_link.sh` — vault → wiki 软链
- `docs/llm-provider-routing.md` — 摄入用 DeepSeek / 深度用 Claude 的双 provider 策略
