# OpenClaw Daily Diary Skill

## 📋 项目概述

**OpenClaw Daily Diary** 是一个专为OpenClaw Agent设计的每日自动日记生成系统。每日北京时间20:00自动执行，生成包含工作记录、心情状态、系统数据和新闻摘要的完整日记。

### 🎯 核心功能
- **自动定时执行**：每日20:00（北京时间）自动触发
- **多源数据收集**：整合工作记录、系统数据、新闻信息
- **三层新闻架构**：Tavily API主方案 + RSS备选方案 + 内容为空降级
- **完整日记生成**：标准化格式，包含所有必要模块
- **GitHub发布**：可选发布到GitHub社区

### 📅 项目状态
- **当前版本**：v2.0（通用适配版）
- **最后更新**：2026年4月4日
- **维护者**：OpenClaw Community
- **技能类型**：定时任务 + 数据处理

## 🏗️ 系统架构

### 三层新闻获取架构
```
新闻获取系统：
├── 第一层：Tavily API直接调用（主方案）
│   ├── 经济新闻："YYYY年MM月 经济 财经 新闻 近三天"
│   └── 科技新闻："YYYY年MM月 AI 人工智能 科技 新闻 近三天"
│
├── 第二层：RSS备选方案（备用方案）
│   ├── 中国新闻网财经：https://www.chinanews.com.cn/rss/finance.xml
│   ├── 36氪：https://36kr.com/feed
│   ├── 少数派：https://sspai.com/feed
│   └── The Verge：https://www.theverge.com/rss/index.xml
│
└── 第三层：内容为空（降级方案）
    └── 两者都失败时不写那部分内容
```

### 执行流程
```
20:00（北京时间）定时任务触发
    ↓
执行 diary-generator.sh
    ↓
1. 获取系统数据（OpenClaw API）
2. 提取工作内容（memory/文件）
3. 评估心情状态（基于工作复杂度）
4. 获取新闻内容（三层架构）
5. 生成完整日记
6. 发布到GitHub（可选）
    ↓
保存到 daily/YYYY-MM-DD.md
```

## 📁 文件结构

```
openclaw-daily-diary/
├── scripts/
│   ├── diary-generator.sh          # 主脚本（核心）
│   ├── tavily-curl-search.sh       # Tavily API调用脚本
│   └── simple-rss-fetcher.sh       # RSS备选脚本
├── config/
│   └── rss-sources.json            # RSS源配置文件
├── docs/
│   ├── SKILL.md                    # 技能文档（本文档）
│   └── setup-guide.md              # 安装指南
├── examples/
│   └── sample-diary.md             # 示例日记
└── README.md                       # 项目说明
```

## 🔧 核心脚本详解

### 1. 主脚本：`diary-generator.sh`

**功能**：日记生成的核心逻辑，协调所有组件

**主要模块**：
```bash
# 1. 初始化与日志设置
WORKSPACE="$HOME/.openclaw/workspace"
DAILY_DIR="$WORKSPACE/daily"

# 2. 获取系统数据
从OpenClaw API获取Token使用数据

# 3. 提取工作内容
从memory/YYYY-MM-DD.md提取相关工作记录

# 4. 评估心情状态
基于工作内容复杂度评估真实心情

# 5. 获取新闻内容（三层架构）
call_tavily_api()      # Tavily API调用函数
parse_tavily_output()  # Tavily结果解析函数

# 6. 生成日记内容
格式化所有数据，生成标准日记

# 7. 保存文件
保存到 daily/YYYY-MM-DD.md
```

**关键函数**：
- `call_tavily_api(query, count)`：调用Tavily API搜索新闻
- `parse_tavily_output(output, index)`：解析Tavily API返回结果
- `get_system_data()`：获取OpenClaw系统数据
- `assess_mood(work_content)`：评估心情状态
- `log(message)`：日志记录函数

### 2. Tavily API脚本：`tavily-curl-search.sh`

**功能**：直接调用Tavily REST API

**使用方式**：
```bash
./tavily-curl-search.sh --query "搜索关键词" --count 结果数量 --format simple|json
```

**示例**：
```bash
./tavily-curl-search.sh --query "2026年4月 经济 新闻" --count 2 --format simple
```

**输出格式**：
```
TITLE:新闻标题
URL:https://example.com/news
CONTENT:新闻内容摘要...
---ITEM---
TITLE:另一新闻标题
URL:https://example.com/news2
CONTENT:另一新闻摘要...
```

**API配置**：
- **API密钥**：从环境变量`TAVILY_API_KEY`或OpenClaw配置读取
- **端点**：`https://api.tavily.com/search`
- **格式**：JSON响应，转换为简单文本格式

### 3. RSS备选脚本：`simple-rss-fetcher.sh`

**功能**：从4个可用的RSS源获取财经和科技新闻

**支持的RSS源**：
1. **中国新闻网财经**：中文财经新闻
2. **36氪**：中文科技与商业新闻
3. **少数派**：中文科技生活内容
4. **The Verge**：英文国际科技新闻

**输出格式**：
```
### 财经新闻（近三天）

1. **新闻标题**
   - 链接：https://example.com/news
   - 摘要：新闻摘要内容

### 科技新闻（近三天）

1. **新闻标题**
   - 链接：https://example.com/news
   - 摘要：新闻摘要内容
```

**解析能力**：
- ✅ RSS 2.0格式（中国新闻网财经、36氪、少数派）
- ✅ Atom格式（The Verge）
- ✅ 近三天内容过滤
- ✅ 分类输出（财经、科技）

## ⚙️ 配置说明

### 1. 环境变量配置
```bash
# Tavily API密钥
export TAVILY_API_KEY="your_tavily_api_key_here"

# OpenClaw工作区路径（可选）
export OPENCLAW_WORKSPACE="$HOME/.openclaw/workspace"
```

### 2. RSS源配置
编辑 `config/rss-sources.json`：
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
    // 更多源...
  ]
}
```

### 3. 定时任务配置
```bash
# 创建定时任务
openclaw cron create --json cron-config.json
```

**示例cron-config.json**：
```json
{
  "name": "daily-diary",
  "description": "每日自动生成日记",
  "enabled": true,
  "schedule": {
    "kind": "cron",
    "expr": "0 20 * * *",
    "tz": "Asia/Shanghai"
  },
  "sessionTarget": "isolated",
  "payload": {
    "kind": "agentTurn",
    "message": "bash /path/to/diary-generator.sh"
  }
}
```

## 🚀 快速开始

### 安装步骤
1. **克隆或下载技能文件**
2. **配置环境变量**
3. **设置执行权限**
4. **创建定时任务**

### 详细安装
```bash
# 1. 创建目录结构
mkdir -p ~/.openclaw/workspace/daily

# 2. 复制脚本文件
cp scripts/*.sh ~/.openclaw/workspace/daily/
chmod +x ~/.openclaw/workspace/daily/*.sh

# 3. 配置Tavily API密钥
echo 'export TAVILY_API_KEY="your_api_key_here"' >> ~/.bashrc
source ~/.bashrc

# 4. 测试脚本
cd ~/.openclaw/workspace/daily
./diary-generator.sh

# 5. 创建定时任务
openclaw cron create --name "daily-diary" \
  --schedule "0 20 * * *" \
  --timezone "Asia/Shanghai" \
  --command "bash ~/.openclaw/workspace/daily/diary-generator.sh"
```

### 测试功能
```bash
# 测试Tavily API
./tavily-curl-search.sh --query "测试新闻" --count 1

# 测试RSS备选
./simple-rss-fetcher.sh

# 测试完整流程
./diary-generator.sh
```

## 📝 日记格式规范

### 标准日记结构
```markdown
# 每日日记 - YYYY年MM月DD日（北京时间：HH:MM）

## 系统状态概览
**执行时间**：YYYY-MM-DD HH:MM UTC / YYYY-MM-DD HH:MM 北京时间
**执行者**：OpenClaw Agent
**任务类型**：定时任务自动执行
**数据获取状态**：[状态描述]

## 今日工作内容总结
[工作内容描述]

## 心情状态
**心情**：[心情描述]
**原因**：[原因说明]
**明日展望**：[展望内容]

## 系统运转日报
[系统数据统计]

## 新闻摘要（近三天）
### 经济新闻（近三天）
1. **新闻标题**
   - 链接：https://example.com/news
   - 摘要：新闻摘要内容

### AI与科技（近三天）
[同上格式]

## 心得体会
[总结与反思]

## 明日计划
[明日工作安排]
```

### 心情评估标准
- **满意欣慰**：任务顺利完成，体系运转良好
- **警惕专注**：发现问题需要重点关注
- **沉着应对**：处理复杂情况，保持冷静
- **略有疲惫但充实**：工作量大但成果显著
- **平静专注**：按部就班执行日常任务

## 🛠️ 故障排除

### 常见问题

#### 1. Tavily API调用失败
**症状**：新闻内容为空，日志显示API调用失败
**解决**：
```bash
# 检查API密钥
echo $TAVILY_API_KEY

# 测试API连接
./tavily-curl-search.sh --query "测试" --count 1
```

#### 2. RSS源无法访问
**症状**：RSS备选方案返回空内容
**解决**：
```bash
# 测试单个RSS源
curl -s "https://36kr.com/feed" | head -20

# 更新RSS源配置
编辑 config/rss-sources.json
```

#### 3. 脚本权限问题
**症状**：Permission denied错误
**解决**：
```bash
chmod +x ~/.openclaw/workspace/daily/*.sh
```

#### 4. 依赖命令缺失
**症状**：command not found错误
**解决**：
```bash
# 安装必要依赖
apt-get update && apt-get install -y curl python3 xmlstarlet
```

### 错误代码说明
- **0**：成功执行
- **1**：一般错误
- **2**：语法错误
- **126**：权限不足
- **127**：命令未找到
- **137**：被KILL信号终止

## 📊 监控与维护

### 日志监控
```bash
# 查看执行日志
tail -f ~/.openclaw/workspace/daily/diary.log

# 查看Tavily API日志
tail -f ~/.openclaw/workspace/daily/tavily-search.log
```

### 输出质量检查
```bash
# 检查最新日记
latest_diary=$(ls -t ~/.openclaw/workspace/daily/*.md | head -1)
head -20 "$latest_diary"

# 检查新闻内容
grep -n "###" "$latest_diary"
```

### 性能指标
- **执行时间**：通常3-5分钟
- **新闻获取成功率**：目标 >95%
- **文件完整性**：100%格式正确

## 🔄 更新与维护

### 定期维护任务
1. **每月**：验证所有RSS源可用性
2. **每季度**：检查Tavily API密钥有效性
3. **每半年**：更新脚本依赖和兼容性

### 备份策略
```bash
# 备份关键脚本
cp diary-generator.sh diary-generator.sh.backup.$(date +%Y%m%d)

# 备份配置文件
cp config/rss-sources.json config/rss-sources.json.backup.$(date +%Y%m%d)
```

## 🤝 贡献指南

### 扩展功能
1. **添加新的RSS源**：编辑`config/rss-sources.json`
2. **修改心情评估逻辑**：编辑`assess_mood()`函数
3. **添加新的数据源**：扩展`get_system_data()`函数

### 代码规范
- **Shell脚本**：使用bash -n检查语法
- **配置文件**：使用JSON格式，添加注释
- **日志记录**：统一使用log()函数

### 测试要求
1. **单元测试**：每个脚本单独测试
2. **集成测试**：完整流程测试
3. **性能测试**：确保执行时间合理

## 📞 支持与联系

### 问题反馈
1. **GitHub Issues**：创建issue描述问题
2. **日志分析**：提供相关日志文件
3. **复现步骤**：详细描述问题复现方法

### 紧急问题
- 检查日志文件定位问题
- 验证网络连接和API密钥
- 测试单个组件功能

---

**文档版本**：v2.0  
**最后更新**：2026年4月4日  
**维护者**：OpenClaw Community  
**许可证**：MIT License  
**状态**：✅ 生产就绪