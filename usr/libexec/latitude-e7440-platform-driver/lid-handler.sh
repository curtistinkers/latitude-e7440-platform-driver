#!/bin/sh

RUN_DIR="/run/latitude-e7440-platform-driver"
SYS_DIR="/sys/class/backlight/intel_backlight"
SAVE_FILE="$RUN_DIR/lid_brightness_save"

# Dynamically locate the stable Lid Switch event file
DEV=$(ls /sys/devices/platform/PNP0C0D:00/input/input*/ | grep -oE "event[0-9]+")

INITIAL_STATE=$(awk '{print $2}' /proc/acpi/button/lid/*/state)
echo "Initializing Dynamic Lid Listener. Device: /dev/input/$DEV, Initial state: $INITIAL_STATE"

while true; do
    # Read exactly one 24-byte kernel input frame unbuffered from the Lid Switch
    event=$(dd if=/dev/input/$DEV bs=24 count=1 2>/dev/null | od -An -v -t x1)
    
    # Check the physical lid state the millisecond an interrupt occurs
    LID_STATE=$(awk '{print $2}' /proc/acpi/button/lid/*/state)
    
    case "$LID_STATE" in
        closed)
            if [ ! -f "$SAVE_FILE" ]; then
                CUR=$(cat "$SYS_DIR/brightness")
                echo "Lid change detected: CLOSED. Saving current brightness ($CUR) and setting screen to 0"
                cat "$SYS_DIR/brightness" > "$SAVE_FILE"
                echo 0 > "$SYS_DIR/brightness"
            fi
            ;;
        open)
            if [ -f "$SAVE_FILE" ]; then
                RESTORED=$(cat "$SAVE_FILE")
                echo "Lid change detected: OPEN. Restoring screen brightness to $RESTORED"
                cat "$SAVE_FILE" > "$SYS_DIR/brightness"
                rm -f "$SAVE_FILE"
            fi
            ;;
    esac
done
