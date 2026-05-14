---
name: phone-camera
description: 通过 ADB + root 控制手机拍照。当用户说「用手机拍照」「拍个照片」「手机拍一张」「帮我拍照」时使用此技能。支持息屏唤醒、解锁、启动相机、截图、拉取文件，覆盖各种手机状态（息屏、锁屏、使用其他程序中、相机已启动）。
---

# 手机拍照技能

通过 ADB 连接手机，使用 root 权限执行 input 命令完成拍照。

## 前置条件

- ADB 已连接（`adb connect 192.168.xxxx:5555`）
- 手机已 root（`su -c id` 返回 uid=0）

## 快速使用

```bash
bash /skills/phone-camera/scripts/snap.sh [输出路径]
```

- 不传参数：输出到工作区，按时间戳命名
- 传路径：保存到指定位置

## 流程

1. 检查 ADB 连接，未连接则自动重连
2. 检查 root 权限
3. `su -c "input keyevent KEYCODE_WAKEUP"` — 亮屏
4. `su -c "input swipe xxxxxxx"` — 上滑解锁
5. `su -c "am force-stop com.android.camera"` — 关闭残留
6. `su -c "am start -n com.android.camera/.Camera"` — 启动相机
7. `sleep 3` — 等待加载
8. `su -c "screencap -p /sdcard/camera_tmp.png"` — 截图
9. `adb pull` — 拉取到本地
10. 清理远程文件，关闭相机

## 注意事项

- 所有 input 命令必须通过 `su -c` 执行，否则因 INJECT_EVENTS 权限被拒
- 截图文件大于 50KB 通常表示正常
- 脚本可重复调用，每次生成唯一时间戳文件名
