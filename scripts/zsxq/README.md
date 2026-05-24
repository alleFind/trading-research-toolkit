# scripts/zsxq · 知识星球增量同步

把你已订阅的知识星球内容**自动增量同步**到本地 Markdown，软链/复制到 trading-review-wiki 的 `raw/sources/zsxq/`，让 wiki 自动摄入。

底层用 [`2dot4/ZsxqCrawler`](https://github.com/2dot4/ZsxqCrawler) 的 `zsxq-md` CLI（V2，最稳定）。

---

## 工作原理

```
浏览器登录知识星球
       │
       ▼ DevTools 拷 Cookie（access_token）
config.toml
       │
       ▼ ./zsxq_daily.sh（每天 cron / launchd / systemd 触发）
ZsxqCrawler.output/articles/YYYY/MM/{topic_id}.md   ← 双层增量同步
       │
       ▼ 软链 / rsync
~/wiki/raw/sources/zsxq/...md
       │
       ▼ trading-review-wiki 自动摄入
wiki/股票/、wiki/题材/、wiki/人物/...
```

**双层增量**：列表游标按 `attached_to_column_time + topic_id`，单条按 `modified_at + content_checksum`。重跑不重复拉，省时省 API 限额。

---

## 一次性安装

### 1. 装依赖

```bash
# 装 uv（Astral 出的 Python 工具链，最快）
curl -LsSf https://astral.sh/uv/install.sh | sh

# clone ZsxqCrawler
git clone https://github.com/2dot4/ZsxqCrawler.git ~/ZsxqCrawler
cd ~/ZsxqCrawler
uv sync       # 装它的 Python 依赖
```

### 2. 拿 Cookie（access_token）

详见 [`docs/zsxq-cookie-sop.md`](../../docs/zsxq-cookie-sop.md)。**30 秒搞定**：

1. Chrome 打开 https://wx.zsxq.com 并登录
2. F12 DevTools → Application → Cookies → `https://wx.zsxq.com`
3. 找到 `zsxq_access_token`，复制 Value
4. 备用：找到目标星球的 group_id（URL 里 `/group/<id>` 那串数字）和专栏 column_id

### 3. 配置

```bash
cd ~/trading-research-toolkit/scripts/zsxq
cp config.toml.example config.toml
$EDITOR config.toml       # 把占位符替换为真实值（access_token、group_id、column_id）
```

> ⚠️ `config.toml` 已被 `.gitignore` 拦，**不会**被 commit。

### 4. 首次全量同步

```bash
./zsxq_daily.sh --full
```

会拉所有历史内容，可能要 5-30 分钟（看星球大小）。输出在：

```
~/ZsxqCrawler/output/articles/YYYY/MM/{topic_id}.md
~/ZsxqCrawler/output/attachments/{topic_id}/...   ← 图片附件
```

### 5. 验证软链生效

```bash
ls -la ~/wiki/raw/sources/zsxq/   # 应该看到一堆 md
```

如果你还没装 trading-review-wiki / 没创建 `~/wiki/`，先跑：

```bash
./zsxq_daily.sh --no-link    # 只抓不软链
```

---

## 日常运行

### 手动跑一次（增量）

```bash
./zsxq_daily.sh
```

### 自动定时

二选一：

**macOS** —— 用 launchd（推荐）：
```bash
cp ~/trading-research-toolkit/configs/launchd/zsxq-daily.plist.example \
   ~/Library/LaunchAgents/com.alleFind.zsxq-daily.plist
# 编辑 plist，把所有 /Users/YOURNAME 替换为你的真实路径
launchctl load ~/Library/LaunchAgents/com.alleFind.zsxq-daily.plist
launchctl start com.alleFind.zsxq-daily
```

**Linux 远端 24×7** —— 用 systemd timer：
```bash
sudo cp ~/trading-research-toolkit/configs/systemd/zsxq-daily.service.example \
        /etc/systemd/system/zsxq-daily.service
sudo cp ~/trading-research-toolkit/configs/systemd/zsxq-daily.timer.example \
        /etc/systemd/system/zsxq-daily.timer
# 编辑两个文件，把 User= 和 路径 改成你的
sudo systemctl daemon-reload
sudo systemctl enable --now zsxq-daily.timer
systemctl list-timers zsxq-daily   # 验证下次触发时间
```

---

## 远端跑还是本地跑？

| 场景 | 推荐 |
|------|------|
| 你 Mac 几乎天天开机 | **launchd** 跑在 Mac，最简单 |
| Mac 经常合盖 / 出差 | **systemd** 跑在远端，定时 rsync 回 Mac |
| 想要"凌晨抓完早上看新内容" | 远端，Mac 醒来后自动 pull |

如果选远端：需要在 `zsxq_daily.sh` 后面加一步把 `~/wiki/raw/sources/zsxq/` rsync 回 Mac，见 `--rsync-to` 选项。

---

## 故障排查

| 症状 | 原因 | 修法 |
|------|------|------|
| `401 Unauthorized` | Cookie 过期 | [SOP](../../docs/zsxq-cookie-sop.md) 重拿 |
| `404 not found group` | group_id 写错或被踢出星球 | 检查 config.toml |
| 拉了但没新内容 | 增量游标已到最新 | 正常，跑 `--full` 强制重拉 |
| 软链失败 | `~/wiki/raw/sources/zsxq/` 不存在 | `mkdir -p` 或装 trading-review-wiki |
| launchd 没执行 | macOS 完全静默 | `tail -f /tmp/zsxq-daily.log` 看输出 |

---

## 命令速查

```bash
./zsxq_daily.sh                    # 增量同步 + 软链
./zsxq_daily.sh --full             # 全量同步（首次或纠错）
./zsxq_daily.sh --no-link          # 只抓，不软链入 wiki
./zsxq_daily.sh --rsync-to user@mac:/path  # 抓完同步到远端 Mac
./zsxq_daily.sh --dry-run          # 不实际执行，看会做什么
./zsxq_daily.sh --help             # 显示帮助
```
