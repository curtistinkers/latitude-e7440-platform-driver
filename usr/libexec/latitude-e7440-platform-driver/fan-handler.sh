#!/bin/sh

RUN_DIR="/run/latitude-e7440-platform-driver"

echo "==> Fan Handler Execution Started <=="

# 1. Dynamically locate whichever hwmon folder holds the dell_smm driver
HWMON_DIR=$(find /sys/class/hwmon/hwmon*/ -name "name" -exec grep -l "dell_smm" {} + | sed 's/\/name//')

if [ -z "$HWMON_DIR" ]; then
    echo "DEBUG ERROR: dell-smm-hwmon driver interface not detected."
    exit 0
fi

# 2. Truly Dynamically discover which temp index is labelled "CPU"
CPU_INDEX=""
for label_file in "$HWMON_DIR"/temp*_label; do
    if [ -f "$label_file" ]; then
        label_text=$(cat "$label_file" 2>/dev/null)
        if [ "$label_text" = "CPU" ]; then
            # Extract the wild card number matching the text (e.g., extracts '1' from 'temp1_label')
            CPU_INDEX=$(basename "$label_file" | grep -oE "[0-9]+")
            break
        fi
    fi
done

# Fallback: If no explicit text label reads "CPU", default gracefully to index 1
if [ -z "$CPU_INDEX" ]; then
    echo "DEBUG: Explicit 'CPU' label not found. Falling back to default index 1."
    CPU_INDEX="1"
else
    echo "DEBUG: Dynamically mapped CPU sensor to index target: temp${CPU_INDEX}"
fi

# 3. Read current CPU temperature integer (converted from millidegrees)
CPU_TEMP=$(cat "$HWMON_DIR/temp${CPU_INDEX}_input" 2>/dev/null)
if [ -z "$CPU_TEMP" ]; then
    echo "DEBUG ERROR: Failed to read temp${CPU_INDEX}_input file."
    exit 0
fi

TEMP=$((CPU_TEMP / 1000))
echo "DEBUG: Raw CPU_TEMP=$CPU_TEMP -> Formatted Celsius=$TEMP°C"

PWM_FILE="$HWMON_DIR/pwm1"
if [ ! -f "$PWM_FILE" ]; then
    echo "DEBUG ERROR: Target PWM file missing at: $PWM_FILE"
    exit 0
fi

# 4. Dynamic Threshold Management Matrix with Hysteresis
STATE_FILE="$RUN_DIR/fan_state"
LAST_PWM=0
[ -f "$STATE_FILE" ] && LAST_PWM=$(cat "$STATE_FILE")

TARGET_PWM=$LAST_PWM

case "$LAST_PWM" in
    0)
        # Fan is off. Turn on Low if we cross 55
        if [ "$TEMP" -ge 55 ]; then
            TARGET_PWM=128
        fi
        ;;
    128)
        # Fan is Low. 
        # Up to High if we cross 70
        if [ "$TEMP" -ge 70 ]; then
            TARGET_PWM=255
        # Down to Off if we drop below 50 (5 degree buffer)
        elif [ "$TEMP" -lt 50 ]; then
            TARGET_PWM=0
        fi
        ;;
    255)
        # Fan is High.
        # Down to Low if we drop below 65 (5 degree buffer)
        if [ "$TEMP" -lt 65 ]; then
            TARGET_PWM=128
        fi
        ;;
    *)
        # Fallback for unknown state: use original thresholds
        if [ "$TEMP" -lt 55 ]; then
            TARGET_PWM=0
        elif [ "$TEMP" -lt 70 ]; then
            TARGET_PWM=128
        else
            TARGET_PWM=255
        fi
        ;;
esac

echo "DEBUG: Last PWM: $LAST_PWM, Current Temp: $TEMP°C -> Evaluated Target PWM: $TARGET_PWM"

# 5. Write speed state adjustments directly to the cooling controller chip
if [ "$TARGET_PWM" -ne "$LAST_PWM" ] || [ ! -f "$STATE_FILE" ]; then
    if echo "$TARGET_PWM" > "$PWM_FILE" 2>&1; then
        echo "DEBUG SUCCESS: Wrote $TARGET_PWM directly to $PWM_FILE"
        echo "$TARGET_PWM" > "$STATE_FILE"
    else
        echo "DEBUG ERROR: Failed to write to $PWM_FILE (Permission or block error)"
    fi
else
    echo "DEBUG: No PWM change required."
fi

echo "==> Fan Handler Execution Finished <=="
