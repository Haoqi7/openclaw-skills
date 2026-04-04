# OpenClaw Custom Skills Collection

一个精心整理的OpenClaw自定义技能集合，包含实用的硬件控制、系统维护和自动化工具。

## ✨ 特性

- **🔧 实用技能**：经过实战检验的生产级技能
- **📚 完整文档**：每个技能都有详细的使用说明
- **⚙️ 开箱即用**：标准化配置，易于集成
- **🔄 持续维护**：定期更新和优化

## 📁 项目结构

```
openclaw-skills/
├── skills/                    # 核心技能目录
│   ├── android-flashlight/   # 安卓闪光灯控制
│   └── session-cleanup-v2/   # 会话清理工具
├── scripts/                  # 辅助脚本
│   ├── daily-diary/         # 每日日记系统脚本
│   └── install-skills.sh    # 一键安装脚本
├── config/                  # 配置文件
│   └── rss-sources.json    # RSS源配置（用于日记系统）
├── cron-tasks/             # 定时任务配置
│   ├── session-cleanup.json
│   └── dashboard-monitor.json
├── docs/                   # 文档
│   └── daily-diary-skill.md
├── examples/               # 示例文件
│   └── sample-daily-diary.md
└── README.md              # 项目说明（本文档）
```

## 🚀 快速开始

### 一键安装
```bash
# 克隆仓库
git clone https://github.com/Haoqi7/openclaw-skills.git
cd openclaw-skills

# 运行安装脚本
./scripts/install-skills.sh
```

### 手动安装特定技能
```bash
# 安装安卓闪光灯技能
cp -r skills/android-flashlight /usr/lib/node_modules/openclaw/skills/

# 安装会话清理技能
cp -r skills/session-cleanup-v2 /usr/lib/node_modules/openclaw/skills/
```

## 📋 技能列表

### 1. Android Flashlight Control
**路径**: `skills/android-flashlight/`

控制安卓手机闪光灯（手电筒）的硬件技能。

**功能**:
- 打开/关闭闪光灯
- 通过Linux sysfs接口直接控制硬件
- 需要root权限

**使用场景**:
- 紧急照明
- 硬件测试
- 自动化控制

**文档**: [skills/android-flashlight/SKILL.md](skills/android-flashlight/SKILL.md)

### 2. Session Cleanup v2
**路径**: `skills/session-cleanup-v2/`

清理OpenClaw过期会话文件的系统维护技能。

**功能**:
- 清理超过12小时的会话文件
- 删除无效索引条目
- 执行OpenClaw内置维护命令

**使用场景**:
- 定期系统清理
- 存储空间优化
- 系统性能维护

**文档**: [skills/session-cleanup-v2/SKILL.md](skills/session-cleanup-v2/SKILL.md)

### 3. Daily Diary System
**路径**: `scripts/daily-diary/`

每日自动生成日记的完整系统，包含新闻获取和数据分析。

**功能**:
- 自动定时执行（每日20:00北京时间）
- 三层新闻获取架构（Tavily API + RSS + 降级）
- 系统状态数据收集
- 智能心情评估
- 标准化日记输出

**核心脚本**:
- `diary-generator.sh` - 主脚本
- `tavily-curl-search.sh` - Tavily API调用
- `simple-rss-fetcher.sh` - RSS备选方案

**文档**: [docs/daily-diary-skill.md](docs/daily-diary-skill.md)

## ⚙️ 配置说明

### 环境变量
```bash
# Tavily API密钥（用于日记系统）
export TAVILY_API_KEY="your_tavily_api_key_here"

# OpenClaw工作区路径
export OPENCLAW_WORKSPACE="$HOME/.openclaw/workspace"
```

### 定时任务配置
预配置的定时任务文件位于 `cron-tasks/` 目录：

1. **会话清理任务** (`session-cleanup.json`)
   - 每天12:00（北京时间）执行
   - 清理过期会话文件

2. **仪表板监控任务** (`dashboard-monitor.json`)
   - 每天9:00和18:00（北京时间）执行
   - 监控OpenClaw仪表板状态

**创建定时任务**:
```bash
openclaw cron create --json cron-tasks/session-cleanup.json
openclaw cron create --json cron-tasks/dashboard-monitor.json
```

## 🛠️ 使用指南

### 安卓闪光灯技能
```bash
# 激活技能（当提到"手电筒"、"闪光灯"时）
# 技能会自动检测并控制 /sys/class/leds/flashlight/brightness

# 手动测试
cd skills/android-flashlight
python3 flashlight.py on   # 打开闪光灯
python3 flashlight.py off  # 关闭闪光灯
```

### 会话清理技能
```bash
# 激活技能（当提到"清理会话"、"session cleanup"时）
# 或通过定时任务自动执行

# 手动执行清理
openclaw sessions cleanup
```

### 每日日记系统
```bash
# 配置环境变量
export TAVILY_API_KEY="your_api_key"

# 测试运行
cd scripts/daily-diary
./diary-generator.sh

# 查看生成的日记
ls -lt ~/.openclaw/workspace/daily/*.md | head -5
```

## 📊 技能对比

| 技能 | 类型 | 复杂度 | 依赖 | 适用场景 |
|------|------|--------|------|----------|
| Android Flashlight | 硬件控制 | 低 | root权限 | 硬件测试、紧急照明 |
| Session Cleanup | 系统维护 | 中 | OpenClaw CLI | 系统优化、存储管理 |
| Daily Diary | 数据处理 | 高 | Tavily API、Python | 自动化报告、数据分析 |

## 🔧 开发与贡献

### 添加新技能
1. 在 `skills/` 目录创建新技能文件夹
2. 包含 `SKILL.md` 文档文件
3. 提供必要的脚本和配置文件
4. 更新本README.md文件

### 技能文档规范
每个技能应包含：
- `SKILL.md` - 完整技能文档
- `README.md` - 简要说明（可选）
- 必要的脚本文件
- 示例或测试文件

### 代码规范
- Shell脚本使用Bash语法
- Python脚本遵循PEP 8
- 配置文件使用JSON格式
- 添加必要的注释

## 🚨 故障排除

### 常见问题

1. **权限问题**
   ```bash
   chmod +x scripts/*.sh
   chmod +x skills/*/*.py
   ```

2. **API密钥错误**
   ```bash
   # 检查Tavily API密钥
   echo $TAVILY_API_KEY
   
   # 测试API连接
   ./scripts/daily-diary/tavily-curl-search.sh --query "测试" --count 1
   ```

3. **OpenClaw命令未找到**
   ```bash
   # 检查OpenClaw安装
   which openclaw
   
   # 检查PATH配置
   echo $PATH
   ```

### 日志文件
- **安装日志**: 查看 `install-skills.sh` 输出
- **日记系统日志**: `~/.openclaw/workspace/daily/diary.log`
- **Tavily API日志**: `~/.openclaw/workspace/daily/tavily-search.log`

## 📄 许可证

MIT License - 详见 [LICENSE](LICENSE) 文件。

## 🤝 贡献

欢迎提交Issue、Pull Request或改进建议！

### 贡献方式
1. Fork本仓库
2. 创建功能分支
3. 提交更改
4. 创建Pull Request

### 开发流程
1. 在本地测试技能功能
2. 更新相关文档
3. 确保向后兼容性
4. 添加必要的测试

## 🙏 致谢

感谢OpenClaw社区和所有贡献者的支持！

---

**版本**: v2.0  
**最后更新**: 2026年4月4日  
**维护者**: Haoqi7  
**状态**: ✅ 生产就绪