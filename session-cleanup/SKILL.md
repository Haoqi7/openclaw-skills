# Session Cleanup Skill

会话清理技能 - 使用 OpenClaw 内置的 `sessions cleanup` 命令清理超时会话。

## 触发条件

- 用户请求清理会话
- 定时任务触发会话清理
- 提到"清理会话"、"会话超时"、"session cleanup"等关键词

## 核心机制

使用增强版清理脚本 `./session_cleanup_final.sh`，该脚本：

- **直接计算6小时时间戳**：确保准确清理超过6小时的会话
- **遍历所有agent目录**：全面清理所有会话文件
- **更新sessions.json**：同步元数据，移除超时会话条目
- **清理残留文件**：删除.deleted等残留文件
- **调用内置命令**：最后调用OpenClaw内置命令确保一致性

## 使用方法

### 手动清理（推荐）

```bash
# 执行增强版清理脚本
./session_cleanup_final.sh

# 或者直接运行OpenClaw命令（功能有限）
openclaw sessions cleanup --enforce --all-agents --fix-missing
```

### 定时任务配置

已配置每天北京时间 13:00 执行，使用增强版脚本清理超过 6 小时的会话：

```json
{
  "name": "清理超6小时会话",
  "schedule": { "kind": "cron", "expr": "0 13 * * *", "tz": "Asia/Shanghai" },
  "sessionTarget": "isolated",
  "payload": {
    "kind": "agentTurn",
    "message": "执行最终版会话清理任务：\n1. 运行最终版清理脚本：`./session_cleanup_final.sh`\n2. 验证清理效果：检查当前会话数量\n\n注意：脚本会直接删除超过6小时的会话文件，并更新sessions.json文件，确保彻底清理超时会话。"
  }
}
```

## 执行步骤

1. **执行增强版清理脚本**
   ```bash
  ./session_cleanup_final.sh
   ```

2. **验证清理效果**
   ```bash
   openclaw sessions --all-agents
   ```

3. **记录结果**


## 参数说明

| 参数 | 说明 |
|------|------|
| `--dry-run` | 预览模式，不实际执行 |
| `--enforce` | 强制执行清理 |
| `--all-agents` | 对所有 agent 执行 |
| `--active-key <key>` | 保护指定会话不被清理 |
| `--fix-missing` | 清理 transcript 文件缺失的会话记录 |

## 脚本位置

增强版清理脚本已部署：

```bash
./session_cleanup_final.sh
```

脚本功能：
- 直接计算6小时时间戳进行清理
- 处理所有agent的会话目录
- 使用jq更新sessions.json文件
- 清理残留文件
- 调用OpenClaw内置命令同步元数据

## 清理规则

1. **运行中会话** - 自动保护，不会被清理
2. **当前任务会话** - 自动保护
3. **所有会话** - 包括 main 会话，超时一律清理

## 输出格式

```markdown
# 会话清理报告

**任务ID**: <cron-id>
**执行时间**: YYYY-MM-DD HH:mm TZ
**阈值**: 6小时

## 清理结果

Agent: taizi
- Entries: N -> M (remove K)
- Would prune stale: X
- Would cap overflow: Y

## 清理统计

- **扫描会话数**: N
- **清理会话数**: K
- **保护会话**: agent:taizi:main

## 结论

<执行结果摘要>


---

