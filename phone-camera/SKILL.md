---
name: phone-camera
description: 通过 ADB + root 控制手机拍照。当用户说「用手机拍照」「拍个照片」「手机拍一张」「帮我拍照」时使用此技能。支持前置/后置摄像头切换、息屏唤醒、解锁、启动相机、拍照、拉取照片，覆盖各种手机状态（息屏、锁屏、使用其他程序中）。
---

# 手机拍照技能

通过 ADB 连接手机，使用 root 权限启动相机并拍照。

## 前置条件

- ADB 已连接（自动检测，未连接则自动重连）
- 手机已 root（`su -c id` 返回 uid=0）

## 快速使用

```bash
# 后置摄像头拍照（默认）
bash /root/.openclaw/workspace-taizi/skills/phone-camera/scripts/snap.sh [输出路径]

# 前置摄像头拍照
bash /root/.openclaw/workspace-taizi/skills/phone-camera/scripts/snap.sh -c front [输出路径]

# 后置摄像头拍照（显式指定）
bash /root/.openclaw/workspace-taizi/skills/phone-camera/scripts/snap.sh -c back [输出路径]
```

- 不传参数：后置摄像头，输出到 `$HOME/snapshots/`，按时间戳命名
- `-c front`：前置摄像头
- `-c back`：后置摄像头（默认）
- 传路径：保存到指定位置

## 拍照流程

1. 检查 ADB 连接，未连接则自动重连
2. 检查 root 权限
3. 亮屏 + 保持常亮（`svc power stayon true`）
4. 上滑解锁
5. 关闭残留相机
6. **启动相机（使用 `STILL_IMAGE_CAMERA` intent 确保进入拍照模式）**
7. **检查当前摄像头 facing，若与目标不符则切换**
8. **切换后验证 facing 是否正确，失败则重试一次**
9. **点击快门按钮拍照（通过 UI dump 获取快门按钮坐标）**
10. 从 `/sdcard/DCIM/Camera/` 拉取最新照片
11. 验证文件大小（>10KB 判定成功）

## 前后置切换机制

### 摄像头 ID 对应关系（小米手机）

| Camera ID | Facing |
|-----------|--------|
| 0, 100, 101, 110, 120, 130 | Back（后置） |
| 1, 60, 61, 62, 63, 200, 210 | Front（前置） |

### 切换方式

1. **UI 自动化点击**：通过 `uiautomator dump` 获取"前后置切换"按钮坐标，`input tap` 点击
2. **切换后必须验证**：通过 `dumpsys media.camera` 检查 `Active Camera Clients` 中的 `Camera ID`，确认 facing 是否正确
3. **最多重试 1 次**：如果切换后验证失败，再点击一次切换按钮

### 关键坐标（小米手机，分辨率 1080x2221）

| 按钮 | 资源 ID | 坐标范围 | 中心点 |
|------|---------|----------|--------|
| 前后置切换 | content-desc="前后置切换" | [784,1934][915,2065] | (850, 2000) |
| 快门按钮 | shutter_button_horizontal | [412,1872][668,2128] | (540, 2000) |

> ⚠️ 坐标可能因手机型号/分辨率不同而变化，脚本会通过 UI dump 动态获取

## 照片验证机制（文件名时间戳 + 分辨率双重验证）

### 1. 新照片识别：按文件名时间戳

文件名格式：`IMG_20260504_230853.jpg`（年月日_时分秒）

拍照前记录当前时间 `YYYYMMDD_HHMMSS`，拍完后遍历照片列表，只保留文件名时间戳大于该值的照片，彻底避免文件系统时间戳不可靠的问题。

### 2. 前后置判断：按分辨率

拍照后通过图片分辨率判断前后置：

| 摄像头 | 分辨率 |
|--------|--------|
| 后置（back） | 1846×4000 |
| 前置（front） | 2392×5184 |

验证流程：拍完照 → 拉取到临时文件 → 用 PIL 获取分辨率 → 匹配目标摄像头 → 匹配则确认成功。

## 关键发现

- **`input tap` 在相机界面可用**（快门按钮、切换按钮均可点击）
- **音量下键**（KEYCODE_VOLUME_DOWN）可触发快门，但在录像模式下会开始/停止录像
- **必须使用 `STILL_IMAGE_CAMERA` intent** 启动相机，否则可能进入录像模式
- 照片保存路径：`/sdcard/DCIM/Camera/IMG_日期_时间.jpg`

## 注意事项

- 所有命令必须通过 `su -c` 执行（INJECT_EVENTS 权限限制）
- 如有 PIN/图案锁，需在 `unlock_screen()` 中添加密码输入逻辑
- 相机启动后需等待 4 秒加载
- **切换摄像头后必须验证 facing**，避免因多次点击导致来回切换
- 脚本会自动判断当前 facing，仅在需要时才执行切换
