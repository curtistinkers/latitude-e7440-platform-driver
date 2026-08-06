#!/bin/sh

SYS_DIR="/sys/class/backlight/intel_backlight"
MAX=$(cat "$SYS_DIR/max_brightness")
STEP=$((MAX / 10))

# Dynamically locate the video bus event file
DEV=$(ls /sys/devices/pci0000:00/acpi.video_bus.0/input/input*/ | grep -oE "event[0-9]+")

echo "Initializing Brightness Key Listener. Device: /dev/input/$DEV, Max Brightness: $MAX, Step Size: $STEP"

while true; do
    event=$(dd if=/dev/input/$DEV bs=24 count=1 2>/dev/null | od -An -v -t x1)
    
    case "$event" in
        *"01 00 e0 00"*)
            CUR=$(cat "$SYS_DIR/brightness")
            NEW=$((CUR - STEP))
            [ $NEW -lt 0 ] && NEW=0
            echo "Key event: BRIGHTNESS_DOWN detected. Changing brightness from $CUR to $NEW"
            echo $NEW > "$SYS_DIR/brightness"
            ;;
        *"01 00 e1 00"*)
            CUR=$(cat "$SYS_DIR/brightness")
            NEW=$((CUR + STEP))
            [ $NEW -gt $MAX ] && NEW=$MAX
            echo "Key event: BRIGHTNESS_UP detected. Changing brightness from $CUR to $NEW"
            echo $NEW > "$SYS_DIR/brightness"
            ;;
    esac
done
