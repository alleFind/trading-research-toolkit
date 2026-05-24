# WeChat 密钥提取 SOP

> 微信群聊接入依赖 `wechat-digest` (cliffyan28/wechat-digest) 从本地 WeChat 加密数据库里解密消息。这一步需要拿到 WeChat 当前进程在内存里的 SQLCipher 密钥。下面是完整 SOP 和踩坑记录。

## 0. 前置条件

| 项 | 要求 |
|---|---|
| 操作系统 | **macOS**（优先）或 Windows。Linux 没有 WeChat 桌面客户端，**不支持** |
| WeChat 版本 | 3.7 及以上 (SQLCipher 4) |
| 状态 | WeChat 必须已登录、在运行；不要在抓密钥过程中扫码 / 登录 / 退出 |
| Python | 3.10+ |
| 权限 | 首次跑 init-keys 需要 sudo（macOS 需要授予终端"完全磁盘访问权限"） |

> ⚠️ 重要：所有密钥与原始聊天记录都是高度敏感数据。这部分内容**禁止**进入任何 git 仓库、云盘、聊天工具。本仓库 `.gitignore` 已排除 `aliases.json` 与 `wechat.env`，但你自己也要确保密钥目录 `~/.wechat-digest/` 永远不被打包。

---

## 1. 安装 wechat-digest

```bash
git clone https://github.com/cliffyan28/wechat-digest.git ~/wechat-digest
cd ~/wechat-digest
pip3 install -r requirements.txt
```

如果用 venv（推荐）：

```bash
cd ~/wechat-digest
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
# 然后在 wechat.env 里把 PYTHON 指向 ~/wechat-digest/.venv/bin/python
```

## 2. macOS 授权（一次性）

1. 系统设置 → 隐私与安全性 → 完全磁盘访问权限
2. 把 `Terminal.app`（或你常用的 iTerm/Warp）加进去并打勾
3. 完全退出终端，重新打开

> 如果忘了这一步，第 3 步抓密钥时会报 `Operation not permitted`。

## 3. 提取密钥

```bash
cd ~/wechat-digest
sudo python3 init-keys.py
```

成功后会生成 `~/.wechat-digest/all_keys.json`，里面是按 wxid 索引的 SQLCipher 密钥。

### 失败常见原因

| 现象 | 原因 | 解决 |
|---|---|---|
| `WeChat process not found` | 微信没运行 | 打开微信，登录后再跑 |
| `Permission denied` 读 `/proc` 或 `/dev/mem` | 没给终端"完全磁盘访问" | 第 2 步重做 |
| 多个 wxid，不知道用哪个 | 同一台机器登过多个号 | 在 keys.json 里挑当前在用的那个 wxid |
| 密钥拿到了但 extract 报 `file is not a database` | WeChat 升级后路径/版本变化 | 升级 wechat-digest 到最新；或查 issue |

## 4. 注册群名

打开 `~/wechat-digest/extract-messages.py`，找到 `known` 字典，加上你要抓的群：

```python
known = {
    # 显示名: chatroom 内部 ID（5xxx...@chatroom）
    "A股研究群": "5123456789@chatroom",
    "光模块讨论组": "5987654321@chatroom",
}
```

`@chatroom` 的 ID 怎么拿？`wechat-digest` 仓库 README 里有 `list-chats.py` 一类的工具，也可以临时改 extract-messages.py 让它 dump 出所有 chatroom 的 (name, id) 配对。

## 5. 验证抓取

```bash
cd ~/wechat-digest
python3 extract-messages.py "A股研究群" 2026-05-24 --hour-offset 0
# 期望产物：output/2026-05-24-A股研究群-聊天记录.md
```

打开看看，能看到时间戳 + 昵称 + 内容就成功了。

## 6. 接入 toolkit

```bash
# 1. 复制 env 模板
cp scripts/wechat/wechat.env.example ~/.config/trading-research-toolkit/wechat.env
# 编辑里面的 GROUPS / WIKI_RAW_DIR / ANONYMIZE 等

# 2. 测试 dry-run
WECHAT_ENV=~/.config/trading-research-toolkit/wechat.env \
  scripts/wechat/wechat_daily.sh 2026-05-24 --dry-run

# 3. 跑一次完整流程
WECHAT_ENV=~/.config/trading-research-toolkit/wechat.env \
  scripts/wechat/wechat_daily.sh 2026-05-24
```

完成后，你的 wiki 目录里会出现：

```
$WIKI_RAW_DIR/wechat/
├── A股研究群/      -> $OUTPUT_DIR/A股研究群/
│   ├── 2026-05-24.md
│   └── 2026-05-25.md
└── 光模块讨论组/
    └── ...
```

trading-review-wiki 主程序就能像处理其它 source 一样把这些文件喂给 LLM 摄入。

## 7. 排定每日任务

详见：

- `configs/launchd/wechat-daily.plist.example`（macOS）
- `configs/systemd/wechat-daily.{service,timer}.example`（Linux 桌面环境）

> 推荐时间 21:30 —— 盘后 + 当天讨论沉淀完，又能赶在你睡前出结果。

## 8. 密钥维护

- 微信每次重大升级（小版本 .x.0）后密钥**可能失效**。重跑 `sudo python3 init-keys.py` 即可。
- 如果换电脑、重装系统、清理过 keychain，密钥也要重抓。
- `all_keys.json` 文件本身要保密。如果泄漏，最坏可能解密你历史所有聊天记录。
- 真要清理：删 `~/.wechat-digest/` 即可，下次需要时重抓。

## 9. 常见疑问

**Q: 这种做法合规吗？**
A: 抓自己机器上、自己微信账号下、自己加入的群的聊天记录，且数据仅本地处理 + 仅你本人查看，在国内大部分场景属于"个人使用"，但**不要分发原始聊天数据**。分享给朋友时应：
- 只分享脚本和 wiki 中"已经 LLM 提炼过的、不含个人身份信息的结论"
- 不分享 raw 文件、聊天截图、群成员 ID

**Q: Windows 怎么办？**
A: 也有类似工具（参考 `ppwwyyxx/wechat-dump` 或其它 fork），但本 toolkit 目前的脚本只在 macOS 测试过。你可以自己 fork 并修改 `wechat_daily.sh` 适配 Windows 的 wechat-digest 等价实现。

**Q: 失败了能恢复吗？**
A: 整个流程是幂等的。重跑 `wechat_daily.sh 2026-05-24` 会重新抓取并覆盖输出。原始数据库本身从不被修改。
