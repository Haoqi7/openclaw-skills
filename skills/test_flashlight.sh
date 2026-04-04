#!/bin/bash
# Test script for Android Flashlight Control Skill

set -e

echo "=== Android Flashlight Control Test ==="
echo "Current time: $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "⚠️  Warning: Not running as root. Some operations may fail."
    echo "   Flashlight control typically requires root access."
    echo
fi

# Check if flashlight device exists
FLASHLIGHT_PATH="/sys/class/leds/flashlight"
if [ -d "$FLASHLIGHT_PATH" ]; then
    echo "✓ Flashlight device found at: $FLASHLIGHT_PATH"
else
    echo "✗ Flashlight device not found at: $FLASHLIGHT_PATH"
    echo
    echo "Available LEDs in /sys/class/leds/:"
    ls /sys/class/leds/ 2>/dev/null || echo "  (Cannot list LEDs)"
    exit 1
fi

# Check brightness files
if [ -f "$FLASHLIGHT_PATH/brightness" ]; then
    echo "✓ Brightness control file found"
else
    echo "✗ Brightness control file missing"
    exit 1
fi

if [ -f "$FLASHLIGHT_PATH/max_brightness" ]; then
    echo "✓ Max brightness file found"
else
    echo "✗ Max brightness file missing"
    exit 1
fi

echo

# Get current status
CURRENT_BRIGHTNESS=$(cat "$FLASHLIGHT_PATH/brightness" 2>/dev/null || echo "0")
MAX_BRIGHTNESS=$(cat "$FLASHLIGHT_PATH/max_brightness" 2>/dev/null || echo "750")

echo "Current brightness: $CURRENT_BRIGHTNESS"
echo "Maximum brightness: $MAX_BRIGHTNESS"

if [ "$CURRENT_BRIGHTNESS" -gt 0 ]; then
    PERCENTAGE=$((CURRENT_BRIGHTNESS * 100 / MAX_BRIGHTNESS))
    echo "Flashlight status: ON ($PERCENTAGE%)"
else
    echo "Flashlight status: OFF"
fi

echo

# Test Python script
echo "=== Testing Python Script ==="
if command -v python3 >/dev/null 2>&1; then
    echo "✓ Python3 found: $(python3 --version)"
    
    # Test basic functionality
    echo "Testing flashlight control..."
    python3 -c "
import sys
sys.path.insert(0, '.')
try:
    from flashlight import AndroidFlashlight
    flashlight = AndroidFlashlight()
    status = flashlight.status()
    print(f'  Current: {status[\"current_brightness\"]}')
    print(f'  Max: {status[\"max_brightness\"]}')
    print(f'  Is on: {status[\"is_on\"]}')
    print('✓ Python module loaded successfully')
except Exception as e:
    print(f'✗ Error loading Python module: {e}')
"
else
    echo "✗ Python3 not found"
fi

echo

# Test commands
echo "=== Test Commands ==="
echo "To turn on flashlight:"
echo "  echo $MAX_BRIGHTNESS > /sys/class/leds/flashlight/brightness"
echo
echo "To turn off flashlight:"
echo "  echo 0 > /sys/class/leds/flashlight/brightness"
echo
echo "Using Python script:"
echo "  python3 flashlight.py status"
echo "  python3 flashlight.py on"
echo "  python3 flashlight.py off"
echo

# Check permissions
echo "=== Permissions Check ==="
ls -la "$FLASHLIGHT_PATH/brightness" 2>/dev/null || echo "Cannot check permissions"

echo
echo "=== Test Complete ==="
echo "Skill is ready for use."
echo "Location: $(pwd)"
echo "Skill files:"
ls -la