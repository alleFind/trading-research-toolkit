# 知识星球 Cookie / Access Token 获取 SOP

每次失效时拿出来用，**30 秒搞定**。

---

## 步骤

### 1. 浏览器登录

Chrome / Edge / Brave 等任一浏览器打开 https://wx.zsxq.com 并登录你自己的账号。

### 2. 打开 DevTools

- macOS: `⌥⌘I` 或右键 → "检查"
- Windows: `F12` 或 `Ctrl+Shift+I`

### 3. 切到 Application 标签

DevTools 顶部一排标签里找 **Application**（中文可能叫"应用"）。

### 4. 找 Cookies

左侧栏：**Storage → Cookies → https://wx.zsxq.com**

### 5. 拷 access_token

右侧表格里找 `zsxq_access_token`（可能也叫 `access_token` 或 `ZSXQ_ACCESS_TOKEN`），**双击 Value 列，全选复制**。

格式形如：
```
ABCDEFAB-1234-5678-90AB-CDEF12345678_FEDCBA9876543210
```

### 6. 粘进 config.toml

```bash
$EDITOR ~/trading-research-toolkit/scripts/zsxq/config.toml
```

找到 `access_token = "..."`，替换里面的占位符。

### 7. 顺便也更新 User-Agent

DevTools → **Network** 标签 → 触发任意一个网络请求（刷新页面）→ 点击任意请求 → **Request Headers** → 找 `User-Agent`，复制完整字符串。

粘进 `config.toml` 的 `user_agent = "..."`。

---

## 拿 group_id（首次配置 / 添加新星球）

1. 浏览器打开你的目标星球
2. 看地址栏 URL：
   ```
   https://wx.zsxq.com/group/88888888888888
                              ^^^^^^^^^^^^^^^^^
                              这就是 group_id
   ```
3. 把 `88888888888888` 填进 `config.toml` 的 `[[groups]]` 段

---

## 拿 column_id（可选，只想同步某些专栏时）

1. 在星球内打开目标专栏
2. 看 URL：
   ```
   https://wx.zsxq.com/group/88888888888888/column/12345
                                                    ^^^^^
                                                    column_id
   ```

---

## 失效频率

| 场景 | Cookie 寿命 |
|------|-----------|
| 浏览器一直登录不退出 | 几周到几个月 |
| 浏览器手动退出登录 | 立即失效 |
| 多设备同时登录 | 互不影响 |
| 修改密码 | 立即全部失效 |

---

## 失效信号

如果 `zsxq_daily.sh` 输出里看到：

```
401 Unauthorized
{"succeeded": false, "code": 401, ...}
```

或者：

```
请先登录
```

那就是 Cookie 失效了，按本 SOP 重新拿一次即可。

---

## 安全提示

- ⚠️ `access_token` 等于"半把账号钥匙"，能读你账号下所有内容（不能改密码、不能付款）
- ⚠️ 永远**不要**贴到 GitHub / 聊天群 / 论坛
- ✅ 只贴在本机 `config.toml`（`.gitignore` 已经排除）
- ✅ 如果不小心泄露：浏览器手动退出登录 → 重新登录 → 旧 token 立即失效
