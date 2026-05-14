#!/bin/bash
# snap.sh - 通过 ADB + root 控制手机拍照
# 用法: bash snap.sh [输出路径]

OUTPUT="${1:-/root/.openclaw/workspace-taizi/camera_$(date +%Y%m%d_%H%M%S).png}"
REMOTE_PATH="/sdcard/camera_tmp.png"

# 通过 su 执行命令
run() {
    adb shell su -c "$1" 2>/dev/null
}

# 检查 ADB
if ! adb get-state >/dev/null 2>&1; then
    echo "ADB 未连接，尝试连接..."
    adb connect 192.168.137.13:5555 >/dev/null 2>&1
    sleep 1
    if ! adb get-state >/dev/null 2>&1; then
        echo "ERROR: ADB 连接失败"
        exit 1
    fi
fi

# 检查 root
if [[ ! "$(run 'id')" =~ "uid=0" ]]; then
    echo "ERROR: 手机未获取 root 权限"
    exit 1
fi

echo "1/6 亮屏..."
run "input keyevent KEYCODE_WAKEUP"
sleep 0.5

echo "2/6 解锁..."
run "input swipe 540 1800 540 800 200"
sleep 1

echo "3/6 关闭残留相机..."
run "am force-stop com.android.camera"
sleep 0.5

echo "4/6 启动相机..."
run "am start -n com.android.camera/.Camera"
sleep 3

echo "5/6 截图..."
run "screencap -p $REMOTE_PATH"

echo "6/6 拉取文件..."
adb pull "$REMOTE_PATH" "$OUTPUT" >/dev/null 2>&1

# 清理
run "am force-stop com.android.camera"
run "rm -f $REMOTE_PATH"

# 验证
if [ -f "$OUTPUT" ]; then
    size=$(stat -c%s "$OUTPUT" 2>/dev/null || stat -f%z "$OUTPUT" 2>/dev/null)
    if [ "$size" -gt 50000 ]; then
        echo "SUCCESS: $OUTPUT (${size} bytes)"
    else
        echo "WARNING: 文件过小 (${size} bytes)"
    fi
else
    echo "ERROR: 截图拉取失败"
    exit 1
fi
