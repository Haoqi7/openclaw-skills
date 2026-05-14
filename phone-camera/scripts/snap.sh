#!/bin/bash
# snap.sh - 通过 ADB + root 控制手机相机拍照
# 用法: bash snap.sh [-c front|back] [输出路径]
#   -c, --camera  指定摄像头：front（前置）或 back（后置），默认 back

set -euo pipefail

# ==================== 参数解析 ====================
CAMERA="back"
OUTPUT=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -c|--camera)
            CAMERA="$2"
            shift 2
            ;;
        *)
            OUTPUT="$1"
            shift
            ;;
    esac
done

OUTPUT="${OUTPUT:-$HOME/snapshots/snap_$(date +%Y%m%d_%H%M%S).jpg}"
REMOTE_DCIM="/sdcard/DCIM/Camera"
REMOTE_PHOTO=""

# 验证摄像头参数
if [[ "$CAMERA" != "front" && "$CAMERA" != "back" ]]; then
    echo "ERROR: 无效的摄像头参数 '$CAMERA'，必须是 front 或 back" >&2
    exit 1
fi

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
    local ip
    ip=$(run_q "ip addr show wlan0 2>/dev/null | grep 'inet ' | awk '{print \$2}' | cut -d/ -f1" | tr -d '\r')
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

# 获取当前激活的摄像头 facing（返回 Back/Front）
get_current_facing() {
    # 从 Active Camera Clients 获取当前使用的 camera ID
    local cam_id
    cam_id=$(run_q "dumpsys media.camera" 2>&1 | grep "Active Camera Clients" -A 5 | grep "Camera ID" | head -1 | grep -oP 'Camera ID: \K\d+') || true
    
    if [ -z "$cam_id" ]; then
        echo "unknown"
        return
    fi
    
    # 根据 camera ID 判断 facing
    # 小米手机：camera ID 0=后置，1=前置，100=后置(另一组)，120=前置(另一组)
    case "$cam_id" in
        0|100|101|110|120|130)
            echo "Back"
            ;;
        1|60|61|62|63|200|210)
            echo "Front"
            ;;
        *)
            # 兜底：通过 camera service 的详细信息判断
            local facing
            facing=$(run_q "dumpsys media.camera" 2>&1 | grep -A 20 "Camera $cam_id" | grep "Facing:" | head -1 | awk '{print $2}') || true
            echo "${facing:-unknown}"
            ;;
    esac
}

# 通过 UI 自动化 dump 获取前后置切换按钮坐标并点击
# 返回：0=成功切换，1=未找到按钮
switch_camera_by_ui() {
    # 先 dump UI
    run_q "uiautomator dump /sdcard/ui_switch.xml" 2>/dev/null
    sleep 0.5
    adb pull /sdcard/ui_switch.xml /tmp/ui_switch.xml 2>/dev/null
    
    if [ ! -f /tmp/ui_switch.xml ]; then
        log "UI dump 失败"
        return 1
    fi
    
    # 使用 python 解析 XML 获取切换按钮坐标
    local bounds
    bounds=$(python3 -c "
import xml.etree.ElementTree as ET
try:
    tree = ET.parse('/tmp/ui_switch.xml')
    for node in tree.getroot().iter('node'):
        desc = node.get('content-desc', '')
        if '切换' in desc or 'switch' in desc.lower():
            print(node.get('bounds', ''))
            break
except:
    pass
" 2>/dev/null) || true
    
    if [ -z "$bounds" ]; then
        log "未找到前后置切换按钮"
        return 1
    fi
    
    # 解析 bounds [x1,y1][x2,y2] -> 中心点 (cx, cy)
    local cx cy
    cx=$(echo "$bounds" | python3 -c "
import sys, re
line = sys.stdin.read().strip()
m = re.match(r'\[(\d+),(\d+)\]\[(\d+),(\d+)\]', line)
if m: print((int(m.group(1))+int(m.group(3)))//2)
" 2>/dev/null) || true
    cy=$(echo "$bounds" | python3 -c "
import sys, re
line = sys.stdin.read().strip()
m = re.match(r'\[(\d+),(\d+)\]\[(\d+),(\d+)\]', line)
if m: print((int(m.group(2))+int(m.group(4)))//2)
" 2>/dev/null) || true
    
    if [ -z "$cx" ] || [ -z "$cy" ]; then
        log "解析切换按钮坐标失败"
        return 1
    fi
    
    log "点击前后置切换按钮 ($cx, $cy)"
    run_q "input tap $cx $cy"
    sleep 2
    
    # 验证切换是否成功：点击后再次检查 facing
    local new_facing
    new_facing=$(get_current_facing)
    log "切换后摄像头: $new_facing"
    
    return 0
}

# 通过 UI 自动化获取快门按钮坐标并点击
tap_shutter_button() {
    run_q "uiautomator dump /sdcard/ui_shutter.xml" 2>/dev/null
    sleep 0.5
    adb pull /sdcard/ui_shutter.xml /tmp/ui_shutter.xml 2>/dev/null
    
    if [ ! -f /tmp/ui_shutter.xml ]; then
        log "UI dump 失败，使用音量键快门"
        run_q "input keyevent 25"
        return
    fi
    
    local bounds
    bounds=$(python3 -c "
import xml.etree.ElementTree as ET
try:
    tree = ET.parse('/tmp/ui_shutter.xml')
    for node in tree.getroot().iter('node'):
        rid = node.get('resource-id', '')
        if 'shutter' in rid:
            print(node.get('bounds', ''))
            break
except:
    pass
" 2>/dev/null) || true
    
    if [ -n "$bounds" ]; then
        local cx cy
        cx=$(echo "$bounds" | python3 -c "
import sys, re
line = sys.stdin.read().strip()
m = re.match(r'\[(\d+),(\d+)\]\[(\d+),(\d+)\]', line)
if m: print((int(m.group(1))+int(m.group(3)))//2)
" 2>/dev/null) || true
        cy=$(echo "$bounds" | python3 -c "
import sys, re
line = sys.stdin.read().strip()
m = re.match(r'\[(\d+),(\d+)\]\[(\d+),(\d+)\]', line)
if m: print((int(m.group(2))+int(m.group(4)))//2)
" 2>/dev/null) || true
        
        if [ -n "$cx" ] && [ -n "$cy" ]; then
            log "点击快门按钮 ($cx, $cy)"
            run_q "input tap $cx $cy"
            return
        fi
    fi
    
    # 兜底：音量下键触发快门
    log "使用音量键快门（兜底）"
    run_q "input keyevent 25"
}

# 前后置摄像头的已知分辨率
# 后置: 1846x4000, 前置: 2392x5184
BACK_WIDTH=1846
BACK_HEIGHT=4000
FRONT_WIDTH=2392
FRONT_HEIGHT=5184

# 获取本地图片的分辨率（返回 宽x高）
get_image_dims() {
    local file="$1"
    # 优先用 identify (ImageMagick)
    if command -v identify &>/dev/null; then
        identify -format "%wx%h" "$file" 2>/dev/null
    else
        # 兜底：用 python3 + PIL
        python3 -c "
from PIL import Image
img = Image.open('$file')
print(f'{img.width}x{img.height}')
" 2>/dev/null
    fi
}

# 根据分辨率判断是前置还是后置（返回 front/back/unknown）
# 支持横屏和竖屏两种方向（拍照时设备方向不同会导致宽高互换）
guess_camera_by_dims() {
    local dims="$1"
    local w h
    w=$(echo "$dims" | cut -dx -f1)
    h=$(echo "$dims" | cut -dx -f2)
    # 后置: 1846x4000 或 4000x1846
    if { [ "$w" = "$BACK_WIDTH" ] && [ "$h" = "$BACK_HEIGHT" ]; } || \
       { [ "$w" = "$BACK_HEIGHT" ] && [ "$h" = "$BACK_WIDTH" ]; }; then
        echo "back"
    # 前置: 2392x5184 或 5184x2392
    elif { [ "$w" = "$FRONT_WIDTH" ] && [ "$h" = "$FRONT_HEIGHT" ]; } || \
         { [ "$w" = "$FRONT_HEIGHT" ] && [ "$h" = "$FRONT_WIDTH" ]; }; then
        echo "front"
    else
        echo "unknown"
    fi
}

# 根据文件名时间戳判断是否为新照片（拍照后拍的）
# 参数1: 拍照前记录的时间戳（格式 YYYYMMDD_HHMMSS）
# 返回: 所有比该时间戳新的照片文件列表（按时间倒序）
find_new_photos_by_name() {
    local before_ts="$1"
    # 提取 before_ts 的数字部分用于比较: YYYYMMDDHHMMSS
    local before_num
    before_num=$(echo "$before_ts" | tr -d '_')
    # 列出所有照片，提取文件名中的时间戳，过滤出比 before 新的
    run_q "ls -t '$REMOTE_DCIM'/IMG_*.jpg 2>/dev/null" | while IFS= read -r f; do
        local fname
        fname=$(basename "$f")
        # IMG_20260504_230853.jpg -> 20260504_230853 -> 20260504230853
        local fnum
        fnum=$(echo "$fname" | sed 's/IMG_//; s/\.jpg//; s/_//')
        if [ "$fnum" -gt "$before_num" ] 2>/dev/null; then
            echo "$f"
        fi
    done
}

# ==================== 主流程 ====================

# 检查 ADB
if ! adb get-state >/dev/null 2>&1; then
    log "ADB 未连接，尝试自动发现..."
    
    if adb devices 2>/dev/null | grep -q 'device$'; then
        log "检测到 USB 设备，尝试切换到网络连接..."
        adb tcpip 5555 >/dev/null 2>&1
        sleep 2
        PHONE_IP=$(get_phone_ip)
        if [ -n "$PHONE_IP" ]; then
            connect_device "$PHONE_IP"
        fi
    fi
    
    if ! adb get-state >/dev/null 2>&1; then
        LOCAL_IP=$(ip route get 1 2>/dev/null | grep -oP 'src \K[\d.]+' | head -1)
        if [ -n "$LOCAL_IP" ]; then
            NET_PREFIX=$(echo "$LOCAL_IP" | cut -d. -f1-3)
            log "扫描网段 ${NET_PREFIX}.x..."
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

# 记录拍照前的时间戳（用于后续按文件名判断新照片）
PHOTO_BEFORE=$(date +%Y%m%d_%H%M%S)
log "拍照前时间戳: $PHOTO_BEFORE"

# 关闭残留相机
log "关闭残留相机..."
run_q "am force-stop com.android.camera"
sleep 1

# 启动相机（使用 STILL_IMAGE_CAMERA intent 确保进入拍照模式）
log "启动相机（拍照模式）..."
run_q "am start -a android.media.action.STILL_IMAGE_CAMERA -n com.android.camera/.Camera"
sleep 4

# 验证相机已启动
if ! is_camera_foreground; then
    log "相机未在前台，重试..."
    run_q "am start -a android.media.action.STILL_IMAGE_CAMERA -n com.android.camera/.Camera"
    sleep 3
    is_camera_foreground || error "相机启动失败"
fi
log "相机已就绪"

# 切换到目标摄像头
CURRENT_FACING=$(get_current_facing)
log "当前摄像头: $CURRENT_FACING，目标: $CAMERA"

if [[ "$CAMERA" == "front" && "$CURRENT_FACING" == "Back" ]] || \
   [[ "$CAMERA" == "back" && "$CURRENT_FACING" == "Front" ]]; then
    log "需要切换摄像头..."
    switch_camera_by_ui || error "切换摄像头失败"
    
    # 二次验证：确保切换成功
    VERIFY_FACING=$(get_current_facing)
    if [[ "$CAMERA" == "front" && "$VERIFY_FACING" != "Front" ]] || \
       [[ "$CAMERA" == "back" && "$VERIFY_FACING" != "Back" ]]; then
        log "WARNING: 切换后验证失败，当前=$VERIFY_FACING，目标=$CAMERA"
        log "尝试再次切换..."
        switch_camera_by_ui
        VERIFY_FACING=$(get_current_facing)
        if [[ "$CAMERA" == "front" && "$VERIFY_FACING" != "Front" ]] || \
           [[ "$CAMERA" == "back" && "$VERIFY_FACING" != "Back" ]]; then
            error "摄像头切换失败：当前=$VERIFY_FACING，目标=$CAMERA"
        fi
    fi
    log "摄像头切换成功: $VERIFY_FACING"
else
    log "摄像头已是目标状态，无需切换"
fi

# 触发快门，带重试
MAX_RETRIES=3
RETRY=0
PHOTO_CONFIRMED=0

while [ $RETRY -lt $MAX_RETRIES ]; do
    log "触发快门... (尝试 $((RETRY+1))/$MAX_RETRIES)"
    tap_shutter_button
    sleep 3

    # 根据文件名时间戳查找新照片（按时间倒序，最新的在前）
    NEW_PHOTOS=$(find_new_photos_by_name "$PHOTO_BEFORE")
    if [ -n "$NEW_PHOTOS" ]; then
        # 遍历新照片，用分辨率判断是否是目标摄像头拍的
        while IFS= read -r candidate; do
            [ -z "$candidate" ] && continue
            # 先拉到临时文件检查分辨率
            TMP_FILE=$(mktemp /tmp/snap_check_XXXXXX.jpg)
            adb pull "$candidate" "$TMP_FILE" >/dev/null 2>&1
            if [ -f "$TMP_FILE" ]; then
                DIMS=$(get_image_dims "$TMP_FILE")
                CAM_GUESS=$(guess_camera_by_dims "$DIMS")
                log "检查 $candidate: 分辨率=$DIMS, 判断=$CAM_GUESS"
                if [ "$CAM_GUESS" = "$CAMERA" ]; then
                    log "分辨率匹配！确认为目标摄像头照片"
                    REMOTE_PHOTO="$candidate"
                    PHOTO_CONFIRMED=1
                    # 用已拉取的临时文件作为最终输出，避免重复拉取
                    mv "$TMP_FILE" "$OUTPUT"
                    break 2
                fi
                rm -f "$TMP_FILE"
            fi
        done <<< "$NEW_PHOTOS"
    fi
    
    RETRY=$((RETRY+1))
    if [ $RETRY -lt $MAX_RETRIES ]; then
        log "未找到匹配照片，等待重试..."
        sleep 2
    fi
done

# 关闭相机
run_q "am force-stop com.android.camera"

# 如果重试后仍未确认，尝试兜底：拉取最新照片并检查
if [ $PHOTO_CONFIRMED -eq 0 ]; then
    log "快门验证未通过，尝试兜底查找..."
    REMOTE_PHOTO=$(find_new_photos_by_name "$PHOTO_BEFORE" | head -1)
    if [ -z "$REMOTE_PHOTO" ] || [ "$REMOTE_PHOTO" = "" ]; then
        REMOTE_PHOTO=$(run_q "ls -t '$REMOTE_DCIM'/IMG_*.jpg 2>/dev/null | head -1" | tr -d '\r')
    fi
    if [ -z "$REMOTE_PHOTO" ] || [ "$REMOTE_PHOTO" = "" ]; then
        error "拍照失败：未找到任何照片文件"
    fi
    log "WARNING: 使用兜底照片，无法确认是否为本次拍照"
fi

log "目标照片: $REMOTE_PHOTO"

# 拉取文件（如果验证阶段已拉取则跳过）
if [ "$PHOTO_CONFIRMED" -eq 1 ] && [ -f "$OUTPUT" ]; then
    log "文件已在验证阶段拉取，跳过重复拉取"
else
    log "拉取文件..."
    adb pull "$REMOTE_PHOTO" "$OUTPUT" >/dev/null 2>&1 || error "文件拉取失败"
fi

# 息屏（拍照完毕后自动息屏）
log "息屏..."
run_q "svc power stayon false"
run_q "input keyevent KEYCODE_POWER"

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
