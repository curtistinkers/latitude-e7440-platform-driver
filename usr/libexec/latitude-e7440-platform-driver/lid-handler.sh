#!/bin/sh
set -eu

RUN_DIR="/run/latitude-e7440-platform-driver"
SYS_DIR="/sys/class/backlight/intel_backlight"
SAVE_FILE="$RUN_DIR/lid_brightness_save"

# Dynamically locate the stable Lid Switch event file using a safe glob loop
DEV=""
for path in /sys/devices/platform/PNP0C0D:00/input/input*/event*; do
    if [ -d "$path" ] || [ -c "$path" ] || [ -e "$path" ]; then
        DEV=$(basename "$path")
        break
    fi
done

if [ -z "$DEV" ]; then
    echo "Error: Lid Switch input event device not found."
    exit 1
fi

INITIAL_STATE=$(awk '{print $2}' /proc/acpi/button/lid/*/state)
echo "Initializing Dynamic Lid Listener. Device: /dev/input/$DEV, Initial state: $INITIAL_STATE"

while true; do
    # Wait for an input event; convert its bytes to printable text, then discard them.
    # The event wakes the loop; the current lid state is read from ACPI below.
    _event=$(dd if="/dev/input/$DEV" bs=24 count=1 2>/dev/null | od -An -v -t x1)
    
    # Read the current ACPI lid state after the event wakes the loop.
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
