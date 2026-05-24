# 朋友加入 · 3 步搭建自己的 A 股研究知识库

适用人群：本组内对 A 股研究有兴趣、愿意花一两个晚上搭一套个人知识库的朋友。

## 你将得到什么

- 一套**本地**的"个股 / 题材 / 模式" 结构化 wiki，由 LLM 自动维护
- **三引擎查询**：自己的私货 + 腾讯财经公开研报 + 朋友策展的行业精选
- 公众号 / 知识星球 / 精选微信群的内容**自动每天同步入库**

## 前置条件

- Mac（macOS 12+，Apple Silicon 或 Intel 都行）
- 微信账号（用来登录 IMA + 用来提取群消息）
- Claude API Key（或 DeepSeek，自己选；trading-review-wiki 里填）
- 半个 ~ 一个晚上时间（按 Sprint 节奏，可以分次做）

---

## 第 1 步 · 装 IMA + 订阅共享库（10 分钟）

1. 装腾讯 IMA：[ima.qq.com](https://ima.qq.com/) 或在微信里搜 `ima 知识库` 小程序
2. 微信扫码登录
3. 进知识库广场，订阅两个库：
   - **腾讯财经 → "最全研报知识库"**（100+ 券商，2020 至今）
   - **三余的行业知识库**（shareId 在群里向三余要）
4. 各 `@` 一下问几个你最近真正纠结的 A 股问题，看效果

> 如果到这一步已经能解决你 70% 需求，可以暂停。后面的步骤是把"私货"也整合进来，让查询更深。

---

## 第 2 步 · 装 trading-review-wiki + 跑通公众号链路（30 分钟）

### 2.1 装桌面 App

从 [trading-review-wiki Releases](https://github.com/ymj8903668-droid/trading-review-wiki/releases) 下 `.dmg`，拖进 Applications。

首次打开如果提示"已损坏"，终端跑：

```bash
xattr -c "/Applications/Trading Review Wiki.app"
```

### 2.2 创建项目

打开 App → 创建新项目 → 选"交易复盘"模板 → 项目目录建议 `~/wiki/`。

### 2.3 配 LLM

进 Settings → Models：
- Provider 选 Anthropic
- 填你的 Claude API Key
- 推荐模型：`claude-3-5-sonnet`（深度分析）+ `claude-3-5-haiku`（高频摄入，便宜）

也可以用 DeepSeek（Provider 选 Custom，base URL 填 `https://api.deepseek.com/v1`）省钱。

### 2.4 装 Obsidian + IMA 同步插件

```bash
# Mac
brew install --cask obsidian
```

打开 Obsidian → 创建 Vault，路径设为 `~/wiki/raw/sources/wechat-mp/`（trading-review-wiki 项目的 sources 目录里新建一个 `wechat-mp/`）。

设置 → 第三方插件 → 关闭安全模式 → 浏览 → 搜 `ima.copilot Sync` → 安装 → 启用。

插件设置里填 IMA Client ID 和 API Key（在 [ima.qq.com](https://ima.qq.com/) 个人中心拿）。

### 2.5 拷模板

```bash
git clone git@github.com:alleFind/trading-research-toolkit.git ~/trading-research-toolkit
cp ~/trading-research-toolkit/templates/purpose.md ~/wiki/purpose.md
cp ~/trading-research-toolkit/templates/schema.md ~/wiki/schema.md
```

### 2.6 验证

1. 在微信里打开任意一篇公众号文章 → 右上角 `...` → 更多打开方式 → `ima 知识库`
2. 等 1 小时（或在 Obsidian 插件设置点"立即同步"）
3. Obsidian 里出现这篇文章 md
4. trading-review-wiki 摄入队列自动跑
5. `~/wiki/wiki/股票/` 出现自动生成的页面

---

## 第 3 步 · 接入星球 + 微信群（按需，分次做）

这部分相对复杂，仓库里有现成脚本。

### 3.1 知识星球（45 分钟）

```bash
cd ~/trading-research-toolkit/scripts/zsxq
cp config.toml.example config.toml
# 编辑 config.toml，填你的 token 和星球 ID（拿法见同目录 README）
./zsxq_daily.sh           # 首次全量
# 装 launchd 定时（见 configs/launchd/）
```

### 3.2 微信群（1-2 小时）

```bash
cd ~/trading-research-toolkit/scripts/wechat
# 跟随同目录 README 装 wechat-digest、拿密钥、配清洗
./wechat_daily.sh         # 测试一次
# 装 launchd 定时
```

---

## 日常使用

| 场景 | 入口 |
|------|------|
| 市场共识 | 微信 → IMA → `@最全研报知识库` |
| 行业精选 | 微信 → IMA → `@三余的行业知识库` |
| 自己的深度复盘 | Mac → trading-review-wiki → 聊天 |
| 看自动生成的个股档案 | Mac → trading-review-wiki → `wiki/股票/` |
| 看知识图谱 | Mac → trading-review-wiki → 图谱视图 |

---

## 遇到问题

1. **trading-review-wiki 报错 "Model provider doesn't serve your region"** → 你的网络出口 IP 在大陆，需要全局/TUN 代理（不是浏览器代理）
2. **IMA 同步插件不动** → 重新登录 IMA，重启 Obsidian
3. **知识星球 Cookie 过期** → 见 `docs/zsxq-cookie-sop.md`（待补）
4. **微信群密钥失效** → 见 `docs/wechat-keys-sop.md`（待补）
5. **其他** → 群里问，或者提 issue 到本仓库

---

## 给本组成员的话

- 别把任何抓取下来的原始数据 commit 到本仓库（`.gitignore` 已经拦了，但自己也注意）
- 脚本/配置/prompt 的改进非常欢迎 PR
- 谁先把某个 SOP 趟出来，记得回来补 `docs/`
