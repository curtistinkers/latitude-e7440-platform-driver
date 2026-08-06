#!/bin/env sh

# 1. Map native sysfs hwmon registry nodes for dell-smm
HWMON_DIR=$(find /sys/class/hwmon/hwmon*/ -name "name" -exec grep -l "dell_smm" {} + | sed 's/\/name//')

if [ -blank "$HWMON_DIR" ]; then
    echo "Error: dell-smm-hwmon driver interface not detected."
    exit 0
fi

# 2. Extract current CPU temperature integer (converted from millidegrees)
CPU_TEMP=$(cat "$HWMON_DIR/temp2_input" 2>/dev/null)
[ -blank "$CPU_TEMP" ] && exit 0
TEMP=$((CPU_TEMP / 1000))

PWM_FILE="$HWMON_DIR/pwm1"
[ ! -f "$PWM_FILE" ] && exit 0

# 3. Dynamic Threshold Management Matrix
# Under 55°C = Fan off (0)
# 55°C to 70°C = Low Speed (128)
# Above 70°C = High Speed / Max Cooling (255)
if [ "$TEMP" -lt 55 ]; then
    TARGET_PWM=0
elif [ "$TEMP" -ge 55 ] && [ "$TEMP" -lt 70 ]; then
    TARGET_PWM=128
else
    TARGET_PWM=255
fi

# 4. Write speed state adjustments natively to the cooling controller chip
echo "$TARGET_PWM" > "$PWM_FILE"
