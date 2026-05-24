# configs/

定时任务和配置模板。

## 目录

| 目录 | 平台 | 加入 Sprint |
|------|------|-----------|
| `launchd/` | macOS（推荐）| S3 |
| `cron/` | Linux | S3 |

## 重要

- 所有 `.plist` / `crontab` 都是 `.example` 文件，**不要**直接 commit 你的真实路径和参数
- 拷贝后改名去掉 `.example`，并加入 `.gitignore`（已经配好）
- macOS 优先用 launchd，cron 在 macOS 上会被 SIP 拦
