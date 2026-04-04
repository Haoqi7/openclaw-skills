# Session Cleanup v2 Skill

## 描述
清理超过12小时的会话文件和无效索引，确保控制面板显示正确。

## 触发条件
- 消息包含: "清理会话", "session cleanup", "cleanup sessions"
- OpenClaw cron任务消息: "SESSION_CLEANUP_TASK"

## 工作流程
1. **Step 1**: 删除超过12小时的 `.jsonl` 会话文件
2. **Step 2**: 清理无效索引（文件不存在或超时的索引条目）
3. **Step 3**: 执行 `openclaw sessions cleanup` 内置维护

## 清理规则
- **会话文件**: 修改时间超过12小时的 `.jsonl` 文件
- **索引条目**: 
  - 对应的 `.jsonl` 文件不存在
  - 或 `updatedAt` 时间戳超过12小时

## 文件位置
- 脚本: `/root/.openclaw/workspace-jinyiwei/scripts/session-cleanup-v2.sh`
- 日志: `/root/.openclaw/workspace-jinyiwei/logs/session-cleanup-YYYYMMDD.log`

## 定时任务
- 任务ID: `efa43e0d-a59c-40a4-b3bd-6f964044216c`
- 执行时间: 每天12:00 (北京时间)
- 触发消息: `SESSION_CLEANUP_TASK`

## 依赖
- Python3 (JSON解析)
- OpenClaw CLI
- jq (可选)