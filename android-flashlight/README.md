# Android Flashlight Control Skill

A skill for controlling Android phone flashlight via Linux sysfs interface.

## Quick Start

```bash
# Turn on flashlight
python3 flashlight.py on

# Turn off flashlight  
python3 flashlight.py off

# Check status
python3 flashlight.py status

# Set custom brightness (0-750)
python3 flashlight.py set --value 100
```

## Features

- **Turn on/off flashlight** - Control phone LED light
- **Brightness control** - Set custom brightness levels
- **Status monitoring** - Check current state
- **Blink mode** - Flashlight blinking (experimental)
- **Device detection** - Auto-detect LED path

## Requirements

- Android device with root access
- Flashlight LED exposed at `/sys/class/leds/flashlight/`
- Python 3.6+ (optional, for Python interface)

## Installation

1. Copy the `android-flashlight` directory to your skills folder:
   ```bash
   cp -r android-flashlight /root/.openclaw/workspace-jinyiwei/skills/
   ```

2. Test the skill:
   ```bash
   cd /root/.openclaw/workspace-jinyiwei/skills/android-flashlight
   ./test_flashlight.sh
   ```

## Usage Examples

### Shell Commands
```bash
# Turn on (max brightness)
echo 750 > /sys/class/leds/flashlight/brightness

# Turn off
echo 0 > /sys/class/leds/flashlight/brightness

# Check current brightness
cat /sys/class/leds/flashlight/brightness
```

### Python API
```python
from flashlight import AndroidFlashlight

# Create flashlight controller
flashlight = AndroidFlashlight()

# Turn on
flashlight.turn_on()

# Check status
status = flashlight.status()
print(f"Brightness: {status['current_brightness']}/{status['max_brightness']}")

# Turn off
flashlight.turn_off()
```

### Agent Integration
Agents can use this skill when users request flashlight control:

```python
# In agent response logic
if "flashlight" in user_request or "手电筒" in user_request:
    # Use the skill
    exec("python3 /path/to/flashlight.py on")
```

## Device Compatibility

Tested on:
- Qualcomm-based Android devices
- Devices with `/sys/class/leds/flashlight/` path
- Rooted Android phones

To check if your device is compatible:
```bash
ls /sys/class/leds/
```

## Troubleshooting

### Permission Denied
```bash
sudo python3 flashlight.py on
# or run as root user
```

### Device Not Found
```bash
# Check available LEDs
ls /sys/class/leds/

# Try alternative path
python3 flashlight.py on --path /sys/class/leds/led:torch_0
```

### Python Module Not Found
```bash
# Ensure you're in the skill directory
cd /path/to/android-flashlight
python3 flashlight.py status
```

## Safety Notes

1. **Heat Management** - Don't leave flashlight on for extended periods
2. **Battery Impact** - Flashlight uses significant power
3. **Root Access** - Required for sysfs write operations
4. **Device Safety** - Only use on compatible Android devices

## License

This skill is part of the OpenClaw skills ecosystem.

## Support

For issues or questions:
1. Check `/sys/class/leds/` directory exists
2. Verify root access
3. Test with `test_flashlight.sh`
4. Contact system administrator