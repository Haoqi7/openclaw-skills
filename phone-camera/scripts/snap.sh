#!/bin/bash
# snap.sh - 通过 ADB + root 控制手机截图
# 用法: bash snap.sh [输出路径]

set -euo pipefail

OUTPUT="${1:-$HOME/snapshots/snap_$(date +%Y%m%d_%H%M%S).png}"
REMOTE_PATH="/sdcard/snap_tmp.png"

# ==================== 函数定义 ====================
log() { echo "[$(date '+%H:%M:%S')] $*" >&2; }
error() { log "ERROR: $*"; exit 1; }

# 通过 su 执行命令
run() {
    adb shell "su -c '$1'" 2>/dev/null
}

# 检查 root 权限
check_root() {
    local result
    result=$(run 'id' 2) || true
    [[ "$result" =~ uid=0 ]]
}

# 自动获取设备 IP
get_device_ip() {
    # 方法1: 从已连接设备获取
    local ip
    ip=$(adb shell "ip addr show wlan0 2>/dev/null | grep 'inet ' | awk '{print \$2}' | cut -d/ -f1" 2>/dev/null)
    
    # 方法2: 如果方法1失败，尝试其他接口
    if [ -z "$ip" ]; then
        ip=$(adb shell "ip addr show wlan0 2>/dev/null || ip addr show eth0 2>/dev/null || ifconfig wlan0 2>/dev/null" | grep -oE 'inet (addr:)?[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    fi
    
    # 方法3: 从 ADB 服务获取（适用于 USB 连接后需要获取 IP）
    if [ -z "$ip" ]; then
        ip=$(adb shell "getprop dhcp.wlan0.ipaddress" 2>/dev/null)
    fi
    
    echo "$ip"
}

# 连接设备
connect_device() {
    local device_ip="$1"
    adb connect "$device_ip:5555" 2>/dev/null
}

# 双击亮屏
double_tap_wake() {
    log "双击亮屏..."
    # 双击屏幕中心偏上位置
    run "input tap 540 1000"
    sleep 0.1
    run "input tap 540 1000"
    sleep 0.5
}

# 按键亮屏（备用）
key_wake() {
    log "按键亮屏..."
    run "input keyevent KEYCODE_WAKEUP"
    sleep 0.5
}

# 检查屏幕状态
is_screen_on() {
    local dump
    dump=$(run "dumpsys power" 2>/dev/null) || true
    echo "$dump" | grep -q "mWakefulness=Awake"
}

# 亮屏（自动选择方法）
wake_screen() {
    if is_screen_on; then
        log "屏幕已亮"
        return 0
    fi
    
    # 检查是否支持双击唤醒
    local double_tap_supported
    double_tap_supported=$(run "settings get system double_tap_to_wake" 2>/dev/null) || true
    
    if [ "$double_tap_supported" = "1" ]; then
        double_tap_wake
        if is_screen_on; then
            log "双击亮屏成功"
            return 0
        fi
    fi
    
    # 尝试双击亮屏（即使设置未开启，某些设备也支持）
    double_tap_wake
    if is_screen_on; then
        return 0
    fi
    
    # 回退到按键亮屏
    key_wake
    if ! is_screen_on; then
        # 再次尝试按键
        run "input keyevent KEYCODE_POWER"
        sleep 0.5
    fi
}

# 解锁屏幕
unlock_screen() {
    log "解锁屏幕..."
    
    # 检查是否在锁屏界面
    local dump
    dump=$(run "dumpsys window" 2>/dev/null) || true
    if ! echo "$dump" | grep -qE 'mDreamingLockscreen|isStatusBarKeyguard|mShowingLockscreen=true'; then
        log "屏幕已解锁"
        return 0
    fi
    
    # 获取屏幕尺寸
    local width height
    read -r width height <<< $(adb shell "wm size" 2>/dev/null | grep -oE '[0-9]+x[0-9]+' | tr 'x' ' ')
    
    # 默认尺寸
    width=${width:-1080}
    height=${height:-1920}
    
    # 计算滑动坐标（从底部30%滑到70%）
    local start_y=$((height * 70 / 100))
    local end_y=$((height * 30 / 100))
    local center_x=$((width / 2))
    
    run "input swipe $center_x $start_y $center_x $end_y 200"
    sleep 1
    
    # 如果还有密码锁，可以在这里添加密码输入
    # run "input text YOUR_PASSWORD"
    # sleep 0.5
    # run "input keyevent KEYCODE_ENTER"
}

# ==================== 主流程 ====================

# 检查 ADB 连接
log "检查 ADB 连接..."
if ! adb get-state >/dev/null 2>&1; then
    log "ADB 未连接，尝试自动连接..."
    
    # 先尝试通过 USB 连接的设备获取 IP
    if adb devices | grep -q 'device$'; then
        DEVICE_IP=$(get_device_ip)
        if [ -n "$DEVICE_IP" ]; then
            log "获取到设备 IP: $DEVICE_IP"
            adb tcpip 5555 2>/dev/null
            sleep 2
            connect_device "$DEVICE_IP"
            sleep 1
        fi
    fi
    
    # 验证连接
    if ! adb get-state >/dev/null 2>&1; then
        error "ADB 连接失败，请确保手机已通过 USB 连接并开启调试模式"
    fi
fi

# 检查 root
log "检查 root 权限..."
check_root || error "手机未获取 root 权限"

# 确保输出目录存在
OUTPUT_DIR=$(dirname "$OUTPUT")
mkdir -p "$OUTPUT_DIR"

# 亮屏
wake_screen

# 解锁
unlock_screen

# 截图
log "开始截图..."
run "screencap -p $REMOTE_PATH" || error "截图失败"

# 拉取文件
log "拉取文件..."
adb pull "$REMOTE_PATH" "$OUTPUT" >/dev/null 2>&1 || error "文件拉取失败"

# 清理远程文件
run "rm -f $REMOTE_PATH" 2>/dev/null || true

# 验证
if [ -f "$OUTPUT" ]; then
    size=$(stat -c%s "$OUTPUT" 2>/dev/null || stat -f%z "$OUTPUT" 2>/dev/null || echo "0")
    if [ "$size" -gt 10000 ]; then
        log "SUCCESS: $OUTPUT (${size} bytes)"
        echo "$OUTPUT"  # 输出路径，方便管道使用
        exit 0
    else
        error "文件过小 (${size} bytes)，可能截图失败"
    fi
else
    error "截图拉取失败"
fi
