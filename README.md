# OpenClaw Skills & Cron Tasks Collection

这是一个OpenClaw自定义技能和定时任务的集合仓库。

## 📦 包含内容

### 1. 自定义技能
- **android-flashlight** - 安卓手机闪光灯控制
- **session-cleanup-v2** - 会话清理工具（清理超过12小时的会话文件）

### 2. 定时任务配置
- **session-cleanup** - 每天12:00（北京时间）清理会话
- **dashboard-monitor** - 每天9:00和18:00（北京时间）监控仪表板状态

## 🚀 快速开始

### 安装技能
```bash
# 复制技能到OpenClaw技能目录
cp -r skills/android-flashlight /path/to/openclaw/skills/
cp -r skills/session-cleanup-v2 /path/to/openclaw/skills/
```

### 创建定时任务
```bash
# 使用OpenClaw CLI创建定时任务
openclaw cron create --json cron-tasks/session-cleanup.json
openclaw cron create --json cron-tasks/dashboard-monitor.json
```

## 🔧 技能详情

### android-flashlight
- **功能**：通过Linux sysfs接口控制安卓手机闪光灯
- **要求**：root权限，闪光灯LED路径 `/sys/class/leds/flashlight/`
- **用法**：`flashlight on` / `flashlight off`

### session-cleanup-v2
- **功能**：清理超过12小时的会话文件和无效索引
- **触发**：消息包含"清理会话"或定时任务`SESSION_CLEANUP_TASK`
- **清理规则**：修改时间超过12小时的`.jsonl`文件

## ⚙️ 定时任务配置

### session-cleanup
- **时间**：每天12:00（北京时间）
- **执行**：发送`SESSION_CLEANUP_TASK`消息触发清理
- **目标**：隔离会话，完成后通知

### dashboard-monitor
- **时间**：每天9:00和18:00（北京时间）
- **执行**：发送`MONITOR_OPENCLAW_DASHBOARD_3010`消息
- **目标**：监控OpenClaw仪表板3010端口状态

## 📁 目录结构
```
.
├── README.md                    # 项目说明
├── skills/                      # 技能目录
│   ├── android-flashlight/      # 安卓闪光灯控制
│   └── session-cleanup-v2/      # 会话清理工具
├── cron-tasks/                  # 定时任务配置
│   ├── session-cleanup.json     # 会话清理任务
│   └── dashboard-monitor.json   # 仪表板监控任务
└── scripts/                     # 辅助脚本
```

## 🔒 安全说明
- 所有上传内容已移除隐私信息（token、密码、个人数据等）
- 定时任务配置中移除了具体的channel ID和敏感配置
- 使用时请根据实际环境修改配置

## 📄 许可证
MIT License