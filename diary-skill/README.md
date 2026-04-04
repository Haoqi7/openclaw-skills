# OpenClaw Daily Diary System

一个功能完整的OpenClaw每日自动日记生成系统，支持多源新闻获取、系统状态监控和标准化日记输出。

## ✨ 特性

- **🕐 自动定时执行**：每日北京时间20:00自动生成日记
- **📰 多源新闻获取**：Tavily API + RSS备选方案，三层降级保障
- **📊 系统状态监控**：集成OpenClaw API获取实时数据
- **😊 智能心情评估**：基于工作内容自动评估心情状态
- **📝 标准化输出**：统一的Markdown格式日记
- **🔧 高度可配置**：支持自定义RSS源、API密钥等

## 🏗️ 系统架构

### 三层新闻获取系统
```
1. 主方案：Tavily API直接调用（实时搜索）
2. 备选方案：RSS源解析（4个可靠源）
3. 降级方案：内容为空（保证系统可用性）
```

### 支持的数据源
- **OpenClaw系统数据**：Token使用、费用统计、活跃Agent
- **工作内容**：从memory文件自动提取
- **新闻信息**：经济新闻 + AI/科技新闻
- **心情状态**：智能评估算法

## 📁 项目结构

```
openclaw-daily-diary/
├── scripts/                    # 核心脚本
│   ├── diary-generator.sh     # 主脚本 - 协调所有组件
│   ├── tavily-curl-search.sh  # Tavily API调用脚本
│   └── simple-rss-fetcher.sh  # RSS备选脚本
├── config/                    # 配置文件
│   └── rss-sources.json      # RSS源配置
├── docs/                     # 文档
│   ├── SKILL.md             # 完整技能文档
│   └── setup-guide.md       # 安装指南
├── examples/                 # 示例文件
│   └── sample-diary.md      # 示例日记
└── README.md                # 项目说明（本文档）
```

## 🚀 快速开始

### 1. 基本安装
```bash
# 克隆或下载项目
git clone https://github.com/yourusername/openclaw-daily-diary.git
cd openclaw-daily-diary

# 创建目标目录
mkdir -p ~/.openclaw/workspace/daily

# 复制脚本文件
cp scripts/*.sh ~/.openclaw/workspace/daily/
chmod +x ~/.openclaw/workspace/daily/*.sh

# 复制配置文件
cp config/rss-sources.json ~/.openclaw/workspace/daily/
```

### 2. 配置API密钥
```bash
# 设置Tavily API密钥（必需）
export TAVILY_API_KEY="your_tavily_api_key_here"

# 持久化配置（可选）
echo 'export TAVILY_API_KEY="your_tavily_api_key_here"' >> ~/.bashrc
```

### 3. 测试运行
```bash
cd ~/.openclaw/workspace/daily

# 测试Tavily API
./tavily-curl-search.sh --query "测试新闻" --count 1

# 测试RSS备选
./simple-rss-fetcher.sh

# 完整测试
./diary-generator.sh
```

### 4. 创建定时任务
```bash
# 使用OpenClaw cron创建定时任务
openclaw cron create \
  --name "daily-diary" \
  --schedule "0 20 * * *" \
  --timezone "Asia/Shanghai" \
  --command "bash ~/.openclaw/workspace/daily/diary-generator.sh" \
  --description "每日自动生成日记"
```

## ⚙️ 配置说明

### 环境变量
| 变量名 | 说明 | 必需 |
|--------|------|------|
| `TAVILY_API_KEY` | Tavily API密钥 | 是 |
| `OPENCLAW_WORKSPACE` | OpenClaw工作区路径 | 否 |

### RSS源配置
编辑 `config/rss-sources.json` 可添加或修改RSS源：
```json
{
  "sources": [
    {
      "name": "中国新闻网财经",
      "url": "https://www.chinanews.com.cn/rss/finance.xml",
      "category": "财经",
      "language": "zh",
      "max_items": 5,
      "days_limit": 3
    }
  ]
}
```

## 📝 输出示例

### 生成的日记文件
日记将保存为 `~/.openclaw/workspace/daily/YYYY-MM-DD.md`，格式如下：

```markdown
# 每日日记 - 2026年4月4日 星期六（北京时间：20:00）

## 系统状态概览
**执行时间**：2026-04-04 12:00 UTC / 2026年4月4日 20:00 北京时间
**执行者**：OpenClaw Agent
**任务类型**：定时任务自动执行

## 今日工作内容总结
[自动提取的工作内容]

## 心情状态
**心情**：平静专注
**原因**：按部就班执行日常任务
**明日展望**：保持当前工作节奏

## 系统运转日报
**Token使用统计**：1250 tokens
**累计费用**：$0.85
**活跃Agent数**：3

## 新闻摘要（近三天）
### 经济新闻（近三天）
1. **新闻标题**
   - 链接：https://example.com/news
   - 摘要：新闻摘要内容...

### AI与科技（近三天）
1. **新闻标题**
   - 链接：https://example.com/news
   - 摘要：新闻摘要内容...

## 心得体会
[自动生成的总结]

## 明日计划
[自动生成的计划]
```

## 🛠️ 故障排除

### 常见问题

1. **Tavily API调用失败**
   ```bash
   # 检查API密钥
   echo $TAVILY_API_KEY
   
   # 测试连接
   ./tavily-curl-search.sh --query "测试" --count 1
   ```

2. **RSS源无法访问**
   ```bash
   # 测试RSS源
   curl -s "https://36kr.com/feed" | head -5
   
   # 更新RSS源配置
   vi config/rss-sources.json
   ```

3. **权限问题**
   ```bash
   chmod +x ~/.openclaw/workspace/daily/*.sh
   ```

4. **依赖缺失**
   ```bash
   # 安装必要工具
   apt-get update && apt-get install -y curl python3
   ```

### 日志文件
- **主日志**：`~/.openclaw/workspace/daily/diary.log`
- **Tavily日志**：`~/.openclaw/workspace/daily/tavily-search.log`

## 🔧 自定义扩展

### 添加新的RSS源
1. 编辑 `config/rss-sources.json`
2. 添加新的源配置
3. 测试源可用性

### 修改心情评估逻辑
编辑 `scripts/diary-generator.sh` 中的 `assess_mood()` 函数。

### 添加新的数据源
扩展 `get_system_data()` 函数以集成更多系统数据。

## 📊 监控与维护

### 查看执行状态
```bash
# 查看定时任务状态
openclaw cron list | grep daily-diary

# 查看最新日记
ls -lt ~/.openclaw/workspace/daily/*.md | head -5

# 查看日志
tail -f ~/.openclaw/workspace/daily/diary.log
```

### 定期维护
- 每月验证RSS源可用性
- 每季度检查API密钥有效性
- 每半年更新脚本兼容性

## 🤝 贡献

欢迎贡献代码、报告问题或提出建议！

### 贡献方式
1. Fork项目
2. 创建功能分支
3. 提交更改
4. 创建Pull Request

### 开发规范
- Shell脚本使用Bash语法检查
- 配置文件使用JSON格式
- 添加必要的注释和文档

## 📄 许可证

MIT License - 详见 LICENSE 文件。

## 🙏 致谢

感谢所有贡献者和OpenClaw社区的支持！

---

**版本**：v2.0  
**最后更新**：2026年4月4日  
**状态**：✅ 生产就绪