---
name: siliconflow-image
description: "基于硅基流动(SiliconFlow) API 的 AI 图片生成与编辑技能，使用 Qwen/Qwen-Image-Edit-2509 模型。支持纯文生图、图片编辑、风格迁移、多图参考。当用户需要生成图片、编辑图片、修改图片、风格迁移、AI 绘图、图片生成、图像编辑，或提到「硅基流动」「SiliconFlow」「Qwen 图片」时，必须使用此技能。即使系统已有其他图片生成工具，只要用户提到硅基流动或明确要求使用 SiliconFlow API，也应优先使用此技能。"
license: MIT
---

# SiliconFlow Image Generation & Editing Skill

基于硅基流动（SiliconFlow）API 的 AI 图片生成与编辑技能，使用 `Qwen/Qwen-Image-Edit-2509` 模型。支持纯文生图、图片编辑、风格迁移、多图参考输入（最多 3 张参考图）。

## 技能路径

**技能位置**: `{project_path}/skills/siliconflow-image`

**核心脚本**: `{技能位置}/scripts/generate.py`

**输出目录**: `{技能位置}/imageoutput/`

## 使用前提

用户必须提供**硅基流动 API Key**。如果用户未提供 API Key，请引导用户前往 https://cloud.siliconflow.cn 注册并获取。

此技能使用 Python 脚本直接调用 SiliconFlow API，**不需要**安装额外的 npm 包或 Python 依赖（仅使用 Python 标准库）。

## 使用方式

### 核心脚本调用

使用 `scripts/generate.py` 脚本来生成或编辑图片。这是一个独立的 Python 3 脚本，直接通过命令行调用即可。

#### 基本用法

```bash
python3 {技能位置}/scripts/generate.py \
  --api-key "用户的API_KEY" \
  --prompt "图片描述文字"
```

#### 完整参数

| 参数 | 必填 | 默认值 | 说明 |
|------|------|--------|------|
| `--api-key` | 是 | 无 | 硅基流动 API Key |
| `--prompt` | 是 | 无 | 图片描述提示词 |
| `--negative-prompt` | 否 | 无 | 反向提示词（不想出现的内容） |
| `--image` | 否 | 无 | 参考图 1（URL 或本地文件路径） |
| `--image2` | 否 | 无 | 参考图 2（URL 或本地文件路径） |
| `--image3` | 否 | 无 | 参考图 3（URL 或本地文件路径） |
| `--num-inference-steps` | 否 | 20 | 推理步数（1-100） |
| `--cfg` | 否 | 4.0 | CFG 值（0.1-20），控制生成图与提示词的匹配度 |
| `--seed` | 否 | 无 | 随机种子（0-9999999999），用于复现结果 |
| `--output-path` | 否 | 自动生成 | 自定义输出文件路径 |

### 使用场景

#### 场景 1：纯文生图

只需提供 `prompt`，不传参考图即可生成全新图片。

```bash
python3 {技能位置}/scripts/generate.py \
  --api-key "sk-xxx" \
  --prompt "一只可爱的橘猫坐在窗台上，窗外是下雨的城市夜景，暖色调，温馨氛围"
```

#### 场景 2：图片编辑

提供 `prompt` + 参考图，对图片进行编辑修改。

```bash
# 使用本地文件
python3 {技能位置}/scripts/generate.py \
  --api-key "sk-xxx" \
  --prompt "给这张图片加上彩虹" \
  --image "/path/to/photo.jpg"

# 使用 URL
python3 {技能位置}/scripts/generate.py \
  --api-key "sk-xxx" \
  --prompt "给这张图片加上彩虹" \
  --image "https://example.com/photo.jpg"
```

#### 场景 3：风格迁移

提供 `prompt` 描述目标风格 + 参考图。

```bash
python3 {技能位置}/scripts/generate.py \
  --api-key "sk-xxx" \
  --prompt "将这张照片转换为宫崎骏动漫风格" \
  --image "/path/to/portrait.jpg"
```

#### 场景 4：多图参考

同时使用多张参考图进行生成（最多 3 张）。

```bash
python3 {技能位置}/scripts/generate.py \
  --api-key "sk-xxx" \
  --prompt "参考第一张图的风格，绘制第二张图中的建筑，使用第三张图的色调" \
  --image "https://example.com/style.jpg" \
  --image2 "https://example.com/building.jpg" \
  --image3 "/path/to/palette.png"
```

#### 场景 5：指定输出路径

```bash
python3 {技能位置}/scripts/generate.py \
  --api-key "sk-xxx" \
  --prompt "一座雪山前的城堡" \
  --output-path "/home/z/my-project/download/castle.png"
```

#### 场景 6：使用种子复现结果

```bash
# 第一次生成
python3 {技能位置}/scripts/generate.py \
  --api-key "sk-xxx" \
  --prompt "一片星空下的湖泊" \
  --seed 12345

# 使用相同种子可复现相同结果
python3 {技能位置}/scripts/generate.py \
  --api-key "sk-xxx" \
  --prompt "一片星空下的湖泊" \
  --seed 12345
```

## 输出说明

脚本会将生成的图片**自动下载并保存**到技能目录下的 `imageoutput/` 文件夹中（除非通过 `--output-path` 指定了其他路径）。

API 返回的图片 URL **仅 1 小时有效**，因此脚本会自动下载保存到本地，避免链接过期。

### 输出结果格式

脚本成功时，向 stdout 输出 JSON：

```json
{
  "success": true,
  "file_path": "/absolute/path/to/imageoutput/img_1713000000.png",
  "url": "https://...",
  "seed": 12345,
  "inference_time_seconds": 12.3,
  "api_inference_ms": 12300,
  "model": "Qwen/Qwen-Image-Edit-2509"
}
```

失败时，向 stderr 输出 JSON：

```json
{
  "success": false,
  "error": "错误描述",
  "error_type": "ValueError"
}
```

### 向用户返回结果

生成完成后，请向用户返回以下信息：
1. **文件保存路径** (`file_path`)，方便用户下载查看
2. 如果有需要，可以将 `url` 提供给用户（提醒 1 小时有效）
3. 返回的 `seed` 值可以让用户用于复现
4. 简要描述生成结果

## 错误处理

脚本已内置完善的错误处理，遇到以下情况会给出明确的中文错误提示：

| 错误类型 | HTTP 状态码 | 提示信息 |
|----------|------------|----------|
| API Key 无效 | 401 | "API Key 无效或未授权，请检查您的硅基流动 API Key" |
| 请求过于频繁 | 429 | "请求频率超限，免费额度为每分钟 2 张、每天 400 张，请稍后重试" |
| 参数错误 | 400 | "请求参数有误：{具体错误信息}" |
| 模型不可用 | 404 | "模型不存在或暂不可用" |
| 服务不可用 | 503 | "硅基流动服务暂时不可用，请稍后重试" |
| 请求超时 | 504 | "请求超时，图片生成时间过长，可尝试减少推理步数" |
| 参考图 URL 无效 | - | "图片 URL 无法访问，请检查链接是否有效" |
| 本地文件不存在 | - | "本地文件未找到：{文件路径}" |
| 网络错误 | - | "网络错误：无法连接到硅基流动 API" |

当脚本返回错误时，请将 `error` 字段的提示信息直接转达给用户。

## API Key 获取

如果用户没有 API Key，引导用户：
1. 访问 https://cloud.siliconflow.cn
2. 注册/登录账号
3. 进入「API 密钥」页面创建密钥
4. 复制 API Key 提供给你

## 参数调优建议

### CFG 值（--cfg）

CFG 控制生成结果与提示词的匹配程度：
- **低值（1-3）**：更自由、更有创意，但可能偏离提示词
- **中值（3-5）**：平衡模式，推荐默认使用 4.0
- **高值（5-10）**：严格遵循提示词，但可能降低多样性
- **太高（>10）**：可能导致画质下降或生成失败

### 推理步数（--num-inference-steps）

- **10-15 步**：生成较快，质量略低
- **20 步**：推荐默认值，质量与速度平衡
- **30-50 步**：质量更好，但耗时更长
- **>50 步**：质量提升不明显，不推荐

### Prompt 编写技巧

好的 prompt 应包含以下要素：
1. **主体**：你想看到什么
2. **风格**：写实、动漫、油画、水彩等
3. **细节**：颜色、光线、氛围、构图
4. **质量词**：high quality、detailed、professional

示例：
- 好："一只毛茸茸的橘猫蜷缩在窗台上，阳光透过薄纱窗帘洒在猫身上，温暖的光影效果，超写实摄影风格，8K 高清"
- 差："一只猫"

## 关于模型

本技能固定使用 `Qwen/Qwen-Image-Edit-2509` 模型。该模型特点：
- 支持纯文生图和图片编辑
- 支持最多 3 张参考图输入
- **不支持** `image_size` 参数（模型自动决定输出尺寸）
- 参考图支持 URL 和 base64 格式
