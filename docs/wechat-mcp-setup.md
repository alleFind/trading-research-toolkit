# wechat-mcp 关键词实时通知（可选）

> 让 Mac 在微信群里出现"持仓股票名 / 跌停 / 暴雷"等关键词时**秒级**弹通知。盘中不用一直盯群。

## 这是什么 / 为什么用

`wechat_daily.sh`（S4）做的是**昨日批量入库**——21:30 跑一次，把昨天的群聊清洗好喂给 wiki。

但盘中如果你的持仓股票被群友突然提到一个**重大消息**，你不会想等到第二天才知道。

`wechat-mcp` 做的是**实时关键词命中通知**：
- 后台轮询微信窗口
- 命中关键词 → macOS 原生通知弹出
- 完全不需要扫码 / 登录 / 部署服务

跟 wiki 的关系：**纯通知，不入库**。命中的消息你点开看，重要的话手动转 IMA 或加备注。如果发现某关键词命中率太高（噪音），调整阈值或换关键词。

## 装机

```bash
git clone https://github.com/Cybing521/wechat-mcp.git ~/wechat-mcp
cd ~/wechat-mcp
npm install
npm run build
```

### macOS 权限授予（一次性）

1. 系统设置 → 隐私与安全性 → **辅助功能**
2. 把 `Terminal.app`（或 iTerm / Warp）加进去，打钩
3. 重启终端

> 这一步如果忘了，wechat-mcp 跑起来不会报错但**通知永远不弹**。

## 配置

新建 `~/.config/trading-research-toolkit/wechat-mcp.json`：

```json
{
  "monitoredGroups": [
    "A股研究群",
    "光模块讨论组",
    "龙头战法交流"
  ],
  "keywords": [
    "中际旭创",
    "300308",
    "002281",
    "光迅",
    "跌停",
    "暴雷",
    "停牌",
    "@所有人",
    "公告",
    "立刻",
    "紧急"
  ],
  "monitoredSenders": [
    "老王",
    "群主"
  ],
  "notificationTitle": "微信群命中",
  "checkInterval": 5000
}
```

字段说明：

| 字段 | 含义 | 推荐值 |
|---|---|---|
| `monitoredGroups` | 要看的群，名字必须跟微信里完全一致 | 跟 `wechat.env` 的 `GROUPS=()` 保持一致 |
| `keywords` | 命中关键词。**任一**命中触发 | 持仓股票名 + 代码 + "跌停"等危险词 |
| `monitoredSenders` | 这些人发的**任何**消息都触发 | 群主、你信任的几个分析师朋友 |
| `notificationTitle` | macOS 通知的标题 | 改成你认得的，跟其它通知区分 |
| `checkInterval` | 轮询间隔（ms） | 5000 = 5 秒；想更快 2000-3000 |

触发逻辑：

```
消息 ∈ monitoredGroups
   且
(消息包含 keywords 任一 OR 消息来自 monitoredSenders 任一)
→ 弹通知
```

## 跑起来

### 临时跑（前台测试）

```bash
cd ~/wechat-mcp
WECHAT_MCP_CONFIG=~/.config/trading-research-toolkit/wechat-mcp.json npm start
```

打开微信，让你的一个朋友在监控群里发 "中际旭创 突破"——5 秒内应该看到 macOS 弹通知。

### 长期跑（后台）

写一个 launchd plist（参考 `configs/launchd/zsxq-daily.plist.example` 的格式），关键字段：

```xml
<key>ProgramArguments</key>
<array>
    <string>/usr/local/bin/node</string>
    <string>/Users/USERNAME/wechat-mcp/dist/server.js</string>
</array>

<key>EnvironmentVariables</key>
<dict>
    <key>WECHAT_MCP_CONFIG</key>
    <string>/Users/USERNAME/.config/trading-research-toolkit/wechat-mcp.json</string>
</dict>

<key>KeepAlive</key>
<true/>

<key>RunAtLoad</key>
<true/>
```

> 注意是 `KeepAlive` + `RunAtLoad`，不是 `StartCalendarInterval`——这是一个**常驻进程**，不是定时任务。

加载：

```bash
launchctl load -w ~/Library/LaunchAgents/com.alleFind.wechat-mcp.plist
launchctl list | grep wechat-mcp   # 看是否在运行
```

## 调优

### 通知太频繁

```
症状: 每 30 秒就弹一次
原因: keywords 太广（如加了"涨"、"跌"）
做法: 删掉过宽的词；改用"涨停"、"跌停"等极端事件
```

### 通知太少 / 漏关键消息

```
症状: 群里在炒一只新股票一整天，你没收到任何通知
原因: 这只股票不在 keywords 里
做法: 调高 keywords 灵敏度；或加一两个"通用风险词"如"利空"、"立案"
推荐: 每周复盘时（见 weekly-review-checklist.md）回顾哪些消息你应该被通知但没被
```

### 通知延迟太大

```
症状: 你点开微信看到一条 1 分钟前的消息现在才弹
原因: checkInterval 太大
做法: 改成 2000-3000 ms；但 macOS 通知系统本身有合并逻辑，太频繁也会被合并
```

### 跟 wechat_daily.sh 的关系

| 工具 | 时机 | 用途 |
|---|---|---|
| **wechat-mcp** | 实时 | 当下知道发生了什么，决定要不要看 |
| **wechat_daily.sh** | 21:30 一次性 | 把全天讨论沉淀成 wiki 可摄入的 markdown |

**两个独立工作**，互不依赖：
- 用 wechat-mcp 不要求装 wechat-digest（mcp 是 AppleScript 读屏，digest 是数据库解密）
- 用 wechat_daily.sh 不要求装 wechat-mcp

但**建议都装**：实时盯 + 隔天沉淀 = 完整覆盖。

## 关键词建议清单

参考给 A 股研究者的初始关键词：

```jsonc
{
  "keywords": [
    // === 持仓股票名（最重要）===
    "中际旭创", "300308",
    "宁德时代", "300750",
    // 加上你自己实际持仓的所有股票

    // === 关注名单 ===
    "光迅科技", "002281",
    // 重要 watch list

    // === 风险事件词 ===
    "跌停", "暴雷", "立案", "停牌", "退市",
    "造假", "财务舞弊", "证监会处罚",
    "黑天鹅", "重大事项",

    // === 机会词 ===
    "涨停", "一字板", "连板",
    "利好", "业绩超预期", "并购",
    "国家队", "外资买入",

    // === 群内 social signal ===
    "@所有人",
    "公告", "急", "重要", "紧急",

    // === 你关注的题材关键词 ===
    "AI算力", "CPO", "光模块",
    "国产替代", "数据要素"
  ]
}
```

> **每月调一次**。一个月运行下来，你会发现哪些词在裸命中（噪音）、哪些词错过了重要消息（漏报）。

## 隐私 / 合规提醒

- wechat-mcp 用 macOS 辅助功能 API**读屏**，不需要数据库密钥
- 数据**不出本机**——通知只在 Mac 本地弹，没有任何上传
- 但**辅助功能权限很危险**——理论上能读任何应用的文本。建议只授权给你信任的终端 / 脚本
- 不要把 `wechat-mcp.json` commit 进任何 git 仓库（本仓库 `.gitignore` 已经拦了 `**/*.local.*`，可以把文件命名为 `wechat-mcp.local.json`）

## 故障排查

### 通知一直不弹

按顺序排查：
1. 系统设置 → 通知 → 终端 / Node → 允许通知打开？
2. 系统设置 → 隐私 → 辅助功能 → 终端打钩？
3. 微信窗口必须**可见**（不能被遮挡 / 不能最小化到 Dock）—— wechat-mcp 是读屏，看不到就读不到
4. checkInterval 设得太大？改成 3000
5. 关键词在群里出现时，**大小写**一致吗？（中文不区分大小写，但英文区分）

### "群名不匹配"

wechat-mcp 用群的**显示名**（你在微信里看到的那个），如果群名被你自己改过（"备注"功能），用你看到的那个，不是群主设置的原名。

### Node 版本不兼容

wechat-mcp 一般要求 Node 18+。`node -v` 看版本。低了的话 `brew install node@20`。

### 不想用了

```bash
launchctl unload ~/Library/LaunchAgents/com.alleFind.wechat-mcp.plist
rm ~/Library/LaunchAgents/com.alleFind.wechat-mcp.plist
# 可选：rm -rf ~/wechat-mcp
```

---

参考：
- 上游：https://github.com/Cybing521/wechat-mcp
- 配套：`scripts/wechat/wechat_daily.sh`（隔天批量入库）
- 配套：`docs/dual-engine-workflow.md`（盘中工作流）
