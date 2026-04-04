# Session Cleanup Handler v2

## 技能描述
处理会话清理任务，使用OpenClaw内置命令清理超过12小时的会话。

## 触发条件
当收到以下任意消息时触发：
- `SESSION_CLEANUP_TASK` (OpenClaw cron触发)
- "清理会话"
- "session cleanup"
- "cleanup sessions"

## 处理流程
1. 接收到触发消息
2. 执行 `/root/.openclaw/workspace-jinyiwei/scripts/session-cleanup-v2.sh`
3. 读取脚本输出和日志
4. 返回清理结果报告
5. 标记任务为成功完成

## 响应模板
```
⚔️ 会话清理任务执行完成 (v2)

📊 清理统计：
- OpenClaw内置清理: {builtin_cleaned} 个无效索引条目
- 手动文件清理: {manual_cleaned} 个超时会话文件
- 总计清理: {total_cleaned} 个项目
- 执行状态: ✅ 成功

📝 详细日志已保存至:
{log_path}
```

## 错误处理
- 如果脚本执行失败，返回错误信息
- 如果无超时会话，仍标记为成功（正常情况）
- 记录所有操作到系统日志

## 集成说明
此技能与 OpenClaw cron 任务集成：
- 触发消息: `SESSION_CLEANUP_TASK`
- 执行脚本: `session-cleanup-v2.sh`
- 执行模式: 独立线程 (isolated session)