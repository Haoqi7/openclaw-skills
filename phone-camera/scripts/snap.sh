#!/bin/bash
# snap.sh - 通过 ADB + root 控制手机相机拍照
# 用法: bash snap.sh [输出路径]

set -euo pipefail

OUTPUT="${1:-$HOME/snapshots/snap_$(date +%Y%m%d_%H%M%S).jpg}"
REMOTE_DCIM="/sdcard/DCIM/Camera"
REMOTE_PHOTO=""

# ==================== 函数定义 ====================
log() { echo "[$(date '+%H:%M:%S')] $*" >&2; }
error() { log "ERROR: $*"; exit 1; }

# 通过 su 执行命令（保留 stderr 用于调试）
run() {
    adb shell su -c "$1" 2>&1
}

# 静默执行（用于不需要输出的命令）
run_q() {
    adb shell su -c "$1" 2>/dev/null
}

check_root() {
    local result
    result=$(adb shell su -c id 2>&1) || true
    [[ "$result" =~ uid=0 ]]
}

# 自动获取手机 IP
get_phone_ip() {
    # 方法1: 从已连接设备获取 wlan0 IP
    local ip
    ip=$(run_q "ip addr show wlan0 2>/dev/null | grep 'inet ' | awk '{print \$2}' | cut -d/ -f1" | tr -d '\r')
    
    # 方法2: getprop
    if [ -z "$ip" ]; then
        ip=$(run_q "getprop dhcp.wlan0.ipaddress" | tr -d '\r')
    fi
    
    echo "$ip"
}

# 连接设备
connect_device() {
    local ip="$1"
    log "尝试连接 $ip:5555..."
    adb connect "$ip:5555" >/dev/null 2>&1
    sleep 1
    adb get-state >/dev/null 2>&1
}

is_screen_on() {
    run_q "dumpsys power" | grep -q "mWakefulness=Awake"
}

wake_screen() {
    if is_screen_on; then
        log "屏幕已亮"
        return 0
    fi
    log "亮屏..."
    run_q "input keyevent KEYCODE_WAKEUP"
    sleep 0.5
    if ! is_screen_on; then
        run_q "input keyevent KEYCODE_POWER"
        sleep 0.5
    fi
    run_q "svc power stayon true"
}

unlock_screen() {
    log "解锁..."
    run_q "input swipe 540 1800 540 800 200"
    sleep 1
}

# 检查相机是否在前台
is_camera_foreground() {
    local focus
    focus=$(run_q "dumpsys window" | grep "mCurrentFocus")
    [[ "$focus" =~ "com.android.camera" ]]
}

# 获取手机上最新照片的时间戳
get_latest_photo_time() {
    run_q "stat -c %Y '$REMOTE_DCIM'/IMG_*.jpg 2>/dev/null | head -1" | tr -d '\r'
}

# 获取手机上最新照片的文件大小
get_latest_photo_size() {
    run_q "stat -c %s '$REMOTE_DCIM'/IMG_*.jpg 2>/dev/null | head -1" | tr -d '\r'
}

# 查找新照片（比指定时间戳新的）
find_new_photo() {
    local after_ts="$1"
    run_q "find '$REMOTE_DCIM' -type f -name 'IMG_*.jpg' -newermt '@$after_ts' 2>/dev/null | head -1" | tr -d '\r'
}

# 获取指定文件的大小
get_file_size() {
    local path="$1"
    run_q "stat -c %s '$path' 2>/dev/null" | tr -d '\r'
}

# ==================== 主流程 ====================

# 检查 ADB
if ! adb get-state >/dev/null 2>&1; then
    log "ADB 未连接，尝试自动发现..."
    
    # 方法1: 尝试从 USB 设备获取 IP 并切换到 TCP/IP
    if adb devices 2>/dev/null | grep -q 'device$'; then
        log "检测到 USB 设备，尝试切换到网络连接..."
        adb tcpip 5555 >/dev/null 2>&1
        sleep 2
        PHONE_IP=$(get_phone_ip)
        if [ -n "$PHONE_IP" ]; then
            connect_device "$PHONE_IP"
        fi
    fi
    
    # 方法2: 扫描本地网络（如果已知网段）
    if ! adb get-state >/dev/null 2>&1; then
        # 尝试从本机路由获取网段
        LOCAL_IP=$(ip route get 1 2>/dev/null | grep -oP 'src \K[\d.]+' | head -1)
        if [ -n "$LOCAL_IP" ]; then
            NET_PREFIX=$(echo "$LOCAL_IP" | cut -d. -f1-3)
            log "扫描网段 ${NET_PREFIX}.x..."
            # 尝试常见 IP（网关、手机常用 IP）
            for suffix in 1 2 100 101 102 103 104 105; do
                if [ "$LOCAL_IP" != "${NET_PREFIX}.${suffix}" ]; then
                    connect_device "${NET_PREFIX}.${suffix}" && break
                fi
            done
        fi
    fi
    
    adb get-state >/dev/null 2>&1 || error "ADB 连接失败，请确保手机已开启 USB 调试或网络调试"
fi
log "ADB 已连接"

# 检查 root
check_root || error "手机未获取 root 权限"
log "Root 权限确认"

# 确保输出目录存在
mkdir -p "$(dirname "$OUTPUT")"

# 亮屏 + 解锁
wake_screen
unlock_screen

# 记录拍照前的最新照片时间和大小（用于后续验证）
PHOTO_BEFORE=$(get_latest_photo_time)
SIZE_BEFORE=$(get_latest_photo_size)
log "拍照前最新照片: 时间=${PHOTO_BEFORE:-无} 大小=${SIZE_BEFORE:-0} bytes"

# 关闭残留相机
log "关闭残留相机..."
run_q "am force-stop com.android.camera"
sleep 1

# 启动相机
log "启动相机..."
run_q "am start -n com.android.camera/.Camera"
sleep 4

# 验证相机已启动
if ! is_camera_foreground; then
    log "相机未在前台，重试..."
    run_q "am start -n com.android.camera/.Camera"
    sleep 3
    is_camera_foreground || error "相机启动失败"
fi
log "相机已就绪"

# 触发快门（音量下键），带重试
MAX_RETRIES=2
RETRY=0
PHOTO_CONFIRMED=0

while [ $RETRY -lt $MAX_RETRIES ]; do
    log "触发快门... (尝试 $((RETRY+1))/$MAX_RETRIES)"
    run_q "input keyevent 25"
    sleep 3

    # 检查是否有新照片且文件大小变化
    NEW_PHOTO=$(find_new_photo "$PHOTO_BEFORE")
    if [ -n "$NEW_PHOTO" ] && [ "$NEW_PHOTO" != "" ]; then
        NEW_SIZE=$(get_file_size "$NEW_PHOTO")
        log "新照片: $NEW_PHOTO (${NEW_SIZE:-0} bytes)"
        
        # 如果有旧照片，比较大小；如果大小不同，说明拍照成功
        if [ -n "$SIZE_BEFORE" ] && [ -n "$NEW_SIZE" ] && [ "$NEW_SIZE" != "$SIZE_BEFORE" ]; then
            log "文件大小变化确认拍照成功 ($SIZE_BEFORE -> $NEW_SIZE)"
            PHOTO_CONFIRMED=1
            REMOTE_PHOTO="$NEW_PHOTO"
            break
        elif [ -z "$SIZE_BEFORE" ] || [ "$SIZE_BEFORE" = "0" ]; then
            # 之前没有照片，新照片就是成功的
            log "首张照片确认成功"
            PHOTO_CONFIRMED=1
            REMOTE_PHOTO="$NEW_PHOTO"
            break
        else
            log "文件大小未变化，可能未拍照成功"
        fi
    else
        log "未检测到新照片"
    fi
    
    RETRY=$((RETRY+1))
    if [ $RETRY -lt $MAX_RETRIES ]; then
        log "等待重试..."
        sleep 2
    fi
done

# 关闭相机
run_q "am force-stop com.android.camera"

# 如果重试后仍未确认，尝试兜底查找
if [ $PHOTO_CONFIRMED -eq 0 ]; then
    log "快门验证未通过，尝试兜底查找..."
    REMOTE_PHOTO=$(find_new_photo "$PHOTO_BEFORE")
    if [ -z "$REMOTE_PHOTO" ] || [ "$REMOTE_PHOTO" = "" ]; then
        REMOTE_PHOTO=$(run_q "ls -t '$REMOTE_DCIM'/IMG_*.jpg 2>/dev/null | head -1" | tr -d '\r')
    fi
    if [ -z "$REMOTE_PHOTO" ] || [ "$REMOTE_PHOTO" = "" ]; then
        error "拍照失败：未找到任何照片文件"
    fi
    log "WARNING: 使用兜底照片，无法确认是否为本次拍照"
fi

log "目标照片: $REMOTE_PHOTO"

# 拉取文件
log "拉取文件..."
adb pull "$REMOTE_PHOTO" "$OUTPUT" >/dev/null 2>&1 || error "文件拉取失败"

# 验证输出
if [ -f "$OUTPUT" ]; then
    size=$(stat -c%s "$OUTPUT" 2>/dev/null || stat -f%z "$OUTPUT" 2>/dev/null || echo "0")
    if [ "$size" -gt 10000 ]; then
        log "SUCCESS: $OUTPUT (${size} bytes)"
        echo "$OUTPUT"
        exit 0
    else
        error "文件过小 (${size} bytes)，可能截图异常"
    fi
else
    error "文件拉取失败"
fi
