# Android Flashlight Control Skill

## Description
Control Android phone flashlight (torch) via Linux sysfs interface. This skill allows agents to turn on/off the phone's flashlight by writing to `/sys/class/leds/flashlight/brightness`.

## Activation
Activate when user mentions:
- Flashlight, torch, phone light
- Android LED control
- Hardware control via sysfs
- `/sys/class/leds/` operations

## Prerequisites
- Root access on Android device
- Flashlight LED exposed at `/sys/class/leds/flashlight/` (common on Qualcomm devices)
- Write permission to brightness file

## Usage

### Basic Commands
```bash
# Turn on flashlight (max brightness)
echo 750 > /sys/class/leds/flashlight/brightness

# Turn off flashlight
echo 0 > /sys/class/leds/flashlight/brightness

# Check current brightness
cat /sys/class/leds/flashlight/brightness

# Check maximum brightness
cat /sys/class/leds/flashlight/max_brightness
```

### Python Script
The skill includes a Python script for programmatic control:

```python
import os
import sys

class AndroidFlashlight:
    """Control Android phone flashlight via sysfs"""
    
    def __init__(self, led_path="/sys/class/leds/flashlight"):
        self.led_path = led_path
        self.brightness_file = os.path.join(led_path, "brightness")
        self.max_brightness_file = os.path.join(led_path, "max_brightness")
        
    def get_max_brightness(self):
        """Get maximum brightness value"""
        try:
            with open(self.max_brightness_file, 'r') as f:
                return int(f.read().strip())
        except Exception as e:
            print(f"Error reading max brightness: {e}")
            return 750  # Default for many devices
    
    def get_current_brightness(self):
        """Get current brightness value"""
        try:
            with open(self.brightness_file, 'r') as f:
                return int(f.read().strip())
        except Exception as e:
            print(f"Error reading current brightness: {e}")
            return 0
    
    def set_brightness(self, value):
        """Set brightness value (0 = off, max = full brightness)"""
        try:
            with open(self.brightness_file, 'w') as f:
                f.write(str(value))
            return True
        except Exception as e:
            print(f"Error setting brightness: {e}")
            return False
    
    def turn_on(self):
        """Turn on flashlight at maximum brightness"""
        max_val = self.get_max_brightness()
        return self.set_brightness(max_val)
    
    def turn_off(self):
        """Turn off flashlight"""
        return self.set_brightness(0)
    
    def status(self):
        """Get flashlight status"""
        current = self.get_current_brightness()
        max_val = self.get_max_brightness()
        return {
            "current_brightness": current,
            "max_brightness": max_val,
            "is_on": current > 0,
            "percentage": (current / max_val * 100) if max_val > 0 else 0
        }

# Command-line interface
if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description="Control Android flashlight")
    parser.add_argument("action", choices=["on", "off", "status", "set"],
                       help="Action to perform")
    parser.add_argument("--value", type=int, help="Brightness value (0-max)")
    parser.add_argument("--path", default="/sys/class/leds/flashlight",
                       help="Path to flashlight LED directory")
    
    args = parser.parse_args()
    flashlight = AndroidFlashlight(args.path)
    
    if args.action == "on":
        if flashlight.turn_on():
            print("Flashlight turned ON")
        else:
            print("Failed to turn on flashlight")
            sys.exit(1)
    
    elif args.action == "off":
        if flashlight.turn_off():
            print("Flashlight turned OFF")
        else:
            print("Failed to turn off flashlight")
            sys.exit(1)
    
    elif args.action == "status":
        status = flashlight.status()
        print(f"Current brightness: {status['current_brightness']}")
        print(f"Maximum brightness: {status['max_brightness']}")
        print(f"Is on: {status['is_on']}")
        print(f"Percentage: {status['percentage']:.1f}%")
    
    elif args.action == "set":
        if args.value is None:
            print("Error: --value required for set action")
            sys.exit(1)
        if flashlight.set_brightness(args.value):
            print(f"Brightness set to {args.value}")
        else:
            print("Failed to set brightness")
            sys.exit(1)
```

## Implementation Notes

### Device Detection
The skill first checks if the flashlight LED path exists:
```bash
if [ -d "/sys/class/leds/flashlight" ]; then
    echo "Flashlight device found"
else
    echo "Flashlight device not found at /sys/class/leds/flashlight/"
    echo "Available LEDs:"
    ls /sys/class/leds/
fi
```

### Alternative LED Paths
Some devices may use different LED names:
- `/sys/class/leds/led:torch_0/`
- `/sys/class/leds/led:flash_0/`
- `/sys/class/leds/torch-light/`

Check available LEDs:
```bash
ls /sys/class/leds/
```

### Safety Considerations
1. **Root Access Required**: Writing to sysfs requires root permissions
2. **Heat Management**: Avoid leaving flashlight on for extended periods
3. **Battery Impact**: Flashlight uses significant power
4. **Device Compatibility**: Works on Qualcomm-based Android devices with exposed sysfs

## Examples

### Agent Usage Pattern
```python
# In agent code
from skills.android_flashlight import AndroidFlashlight

flashlight = AndroidFlashlight()
if flashlight.turn_on():
    print("Flashlight activated")
    # Do something...
    flashlight.turn_off()
```

### Shell Commands in Agent
```bash
# Turn on
exec("echo 750 > /sys/class/leds/flashlight/brightness")

# Turn off  
exec("echo 0 > /sys/class/leds/flashlight/brightness")

# Check status
exec("cat /sys/class/leds/flashlight/brightness")
```

## Troubleshooting

### Common Issues
1. **Permission denied**: Ensure running as root
2. **Device not found**: Check LED path with `ls /sys/class/leds/`
3. **Invalid value**: Check max brightness with `cat /sys/class/leds/flashlight/max_brightness`

### Debug Commands
```bash
# Check permissions
ls -la /sys/class/leds/flashlight/brightness

# Test write permission
echo 1 > /sys/class/leds/flashlight/brightness 2>&1

# List all available LEDs
find /sys/class/leds/ -name "brightness" -exec dirname {} \;
```

## References
- [Linux LED Class Documentation](https://www.kernel.org/doc/html/latest/leds/leds-class.html)
- [Android Hardware Abstraction Layer](https://source.android.com/docs/core/architecture/hal)
- [Qualcomm LED Driver](https://github.com/torvalds/linux/tree/master/drivers/leds)

## Skill Files
- `SKILL.md` - This documentation
- `flashlight.py` - Python implementation
- `test_flashlight.sh` - Shell test script