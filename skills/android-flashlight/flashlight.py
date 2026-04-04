#!/usr/bin/env python3
"""
Android Flashlight Control
Control Android phone flashlight via sysfs interface
"""

import os
import sys
import argparse

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
        except FileNotFoundError:
            print(f"Error: Flashlight device not found at {self.led_path}")
            print("Available LEDs in /sys/class/leds/:")
            try:
                leds = os.listdir("/sys/class/leds/")
                for led in leds:
                    print(f"  - {led}")
            except:
                pass
            sys.exit(1)
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
            # Validate value
            max_val = self.get_max_brightness()
            if value < 0 or value > max_val:
                print(f"Error: Brightness value must be between 0 and {max_val}")
                return False
            
            with open(self.brightness_file, 'w') as f:
                f.write(str(value))
            return True
        except PermissionError:
            print("Error: Permission denied. Need root access to control flashlight.")
            print("Run with sudo or as root user.")
            sys.exit(1)
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
    
    def blink(self, count=3, duration=0.5):
        """Blink flashlight (experimental)"""
        import time
        max_val = self.get_max_brightness()
        
        for i in range(count):
            self.set_brightness(max_val)
            time.sleep(duration)
            self.set_brightness(0)
            if i < count - 1:
                time.sleep(duration)
        
        return True

def main():
    """Command-line interface"""
    parser = argparse.ArgumentParser(
        description="Control Android phone flashlight via sysfs",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s on                    # Turn on flashlight
  %(prog)s off                   # Turn off flashlight
  %(prog)s status                # Check flashlight status
  %(prog)s set --value 100       # Set brightness to 100
  %(prog)s on --path /sys/class/leds/led:torch_0  # Use alternative LED path
        """
    )
    
    parser.add_argument("action", choices=["on", "off", "status", "set", "blink"],
                       help="Action to perform")
    parser.add_argument("--value", type=int, help="Brightness value (0-max)")
    parser.add_argument("--path", default="/sys/class/leds/flashlight",
                       help="Path to flashlight LED directory")
    parser.add_argument("--count", type=int, default=3,
                       help="Number of blinks (for blink action)")
    parser.add_argument("--duration", type=float, default=0.5,
                       help="Duration of each blink in seconds")
    
    args = parser.parse_args()
    flashlight = AndroidFlashlight(args.path)
    
    if args.action == "on":
        if flashlight.turn_on():
            status = flashlight.status()
            print(f"✓ Flashlight turned ON (brightness: {status['current_brightness']}/{status['max_brightness']})")
        else:
            print("✗ Failed to turn on flashlight")
            sys.exit(1)
    
    elif args.action == "off":
        if flashlight.turn_off():
            print("✓ Flashlight turned OFF")
        else:
            print("✗ Failed to turn off flashlight")
            sys.exit(1)
    
    elif args.action == "status":
        status = flashlight.status()
        print(f"Flashlight Status:")
        print(f"  Current brightness: {status['current_brightness']}")
        print(f"  Maximum brightness: {status['max_brightness']}")
        print(f"  Is on: {'Yes' if status['is_on'] else 'No'}")
        print(f"  Percentage: {status['percentage']:.1f}%")
    
    elif args.action == "set":
        if args.value is None:
            print("Error: --value required for set action")
            sys.exit(1)
        if flashlight.set_brightness(args.value):
            print(f"✓ Brightness set to {args.value}")
        else:
            print("✗ Failed to set brightness")
            sys.exit(1)
    
    elif args.action == "blink":
        print(f"Blinking flashlight {args.count} times...")
        if flashlight.blink(args.count, args.duration):
            print(f"✓ Completed {args.count} blinks")
        else:
            print("✗ Failed to blink flashlight")
            sys.exit(1)

if __name__ == "__main__":
    main()