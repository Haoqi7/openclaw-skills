# OpenClaw Custom Skills Collection

一个精心整理的OpenClaw自定义技能集合，每个技能都有独立的文件夹，便于查找和使用。

## 📁 项目结构

```
openclaw-skills/
├── android-flashlight/          # 安卓闪光灯控制技能
├── daily-diary/                 # 每日日记系统技能
├── session-cleanup/             # 会话清理技能
├── siliconflow-image/           # 硅基流动支持的生图
├── LICENSE                      # MIT许可证
└── README.md                    # 项目说明（本文档）
```

## 🚀 快速开始


### 手动安装特定技能
```bash
# 安装安卓闪光灯技能
cp -r android-flashlight /usr/lib/node_modules/openclaw/skills/

# 安装会话清理技能
cp -r session-cleanup /usr/lib/node_modules/openclaw/skills/

# 安装每日日记系统
mkdir -p ~/.openclaw/workspace/daily
cp daily-diary/*.sh ~/.openclaw/workspace/daily/
chmod +x ~/.openclaw/workspace/daily/*.sh
```

## 📋 技能详情

### 1. Android Flashlight Control
**文件夹**: `android-flashlight/`

控制安卓手机闪光灯（手电筒）的硬件技能。

**包含文件**:
- `SKILL.md` - 完整技能文档
- `README.md` - 简要说明
- `flashlight.py` - Python控制脚本
- `test_flashlight.sh` - 测试脚本

**功能**:
- 打开/关闭闪光灯
- 通过Linux sysfs接口直接控制硬件
- 需要root权限

**使用场景**:
- 紧急照明
- 硬件测试
- 自动化控制

### 2. Daily Diary System
**文件夹**: `daily-diary/`

每日自动生成日记的完整系统，包含新闻获取和数据分析。

**包含文件**:
- `daily-diary-skill.md` - 完整技能文档
- `diary-generator.sh` - 主脚本
- `tavily-curl-search.sh` - Tavily API调用脚本
- `simple-rss-fetcher.sh` - RSS备选脚本
- `rss-sources.json` - RSS源配置
- `sample-daily-diary.md` - 示例日记

**功能**:
- 自动定时执行（每日20:00北京时间）
- 三层新闻获取架构（Tavily API + RSS + 降级）
- 系统状态数据收集
- 智能心情评估
- 标准化日记输出

### 3. Session Cleanup
**文件夹**: `session-cleanup/`

清理OpenClaw过期会话文件的系统维护技能。

**包含文件**:
- `SKILL.md` - 完整技能文档
- `handler.md` - 处理逻辑说明

**功能**:
- 清理超过12小时的会话文件
- 删除无效索引条目
- 执行OpenClaw内置维护命令

**使用场景**:
- 定期系统清理
- 存储空间优化
- 系统性能维护
### 4. siliconflow-image生图，编辑图
siliconflow-image/
├── SKILL.md                  # 技能配置与说明文件（技能入口）
├── LICENSE.txt               # MIT 开源协议
├── scripts/
│   └── generate.py           # 核心脚本（纯 Python 标准库，无额外依赖）
└── imageoutput/
    └── README.md             # 图片输出目录


**本技能固定使用 `Qwen/Qwen-Image-Edit-2509` 模型。该模型特点：**
- 支持纯文生图和图片编辑
- 支持最多 3 张参考图输入
- **不支持** `image_size` 参数（模型自动决定输出尺寸）
- 参考图支持 URL 和 base64 格式
- 需要硅基流动apikey


## ⚙️ 配置说明

### 环境变量
```bash
# Tavily API密钥（用于日记系统）
export TAVILY_API_KEY="your_tavily_api_key_here"

# OpenClaw工作区路径
export OPENCLAW_WORKSPACE="$HOME/.openclaw/workspace"
```


## 🛠️ 使用指南

### 安卓闪光灯技能
```bash
cd android-flashlight

# 测试闪光灯
python3 flashlight.py on   # 打开闪光灯
python3 flashlight.py off  # 关闭闪光灯

# 运行测试脚本
./test_flashlight.sh
```

### 每日日记系统
```bash
cd daily-diary

# 配置环境变量
export TAVILY_API_KEY="your_api_key"

# 测试运行
./diary-generator.sh

# 测试Tavily API
./tavily-curl-search.sh --query "测试新闻" --count 1

# 测试RSS备选
./simple-rss-fetcher.sh
```

### 会话清理技能
```bash
# 查看技能文档
cat session-cleanup/SKILL.md

# 手动执行清理
openclaw sessions cleanup
```



## 📊 技能对比

| 技能 | 文件夹 | 类型 | 复杂度 | 依赖 |
|------|--------|------|--------|------|
| Android Flashlight | `android-flashlight/` | 硬件控制 | 低 | root权限 |
| Daily Diary | `daily-diary/` | 数据处理 | 高 | Tavily API、Python |
| Session Cleanup | `session-cleanup/` | 系统维护 | 中 | OpenClaw CLI |

## 🔧 开发与贡献

### 添加新技能
1. 创建新的技能文件夹（如 `new-skill/`）
2. 包含必要的文档和脚本文件
3. 更新本README.md文件
4. 测试技能功能

### 技能文档规范
每个技能文件夹应包含：
- `SKILL.md` 或 `README.md` - 技能文档
- 必要的脚本文件
- 配置文件（如果需要）
- 示例或测试文件

## 🚨 故障排除

### 常见问题

1. **权限问题**
   ```bash
   chmod +x daily-diary/*.sh
   chmod +x android-flashlight/*.py
   ```

2. **API密钥错误**
   ```bash
   # 检查Tavily API密钥
   echo $TAVILY_API_KEY
   
   # 测试API连接
   cd daily-diary
   ./tavily-curl-search.sh --query "测试" --count 1
   ```

3. **OpenClaw命令未找到**
   ```bash
   # 检查OpenClaw安装
   which openclaw
   
   # 检查PATH配置
   echo $PATH
   ```

## 📄 许可证

MIT License - 详见 [LICENSE](LICENSE) 文件。

## 🤝 贡献

欢迎提交Issue、Pull Request或改进建议！

### 贡献方式
1. Fork本仓库
2. 创建功能分支
3. 提交更改
4. 创建Pull Request

## 🙏 致谢

感谢OpenClaw社区和所有贡献者的支持！

---

**版本**: v2.1  
**最后更新**: 2026年4月4日  
**维护者**: Haoqi7  
**状态**: ✅ 生产就绪
