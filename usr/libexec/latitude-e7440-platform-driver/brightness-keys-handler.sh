#!/bin/sh
set -eu

SYS_DIR="/sys/class/backlight/intel_backlight"
MAX=$(cat "$SYS_DIR/max_brightness")
STEP=$((MAX / 10))

case "$1" in
    down)
        CUR=$(cat "${SYS_DIR}/brightness")
        NEW=$((CUR - STEP))
        [ "${NEW}" -lt 0 ] && NEW=0
        printf "BRIGHTNESSDOWN detected: "
        if [ "${NEW}" -eq 0 ]; then
            printf "Screen backlight is off."
        else
            printf "Changing brightness from %s to %s." "${CUR}" "${NEW}"
        fi
        echo "${NEW}" > "${SYS_DIR}/brightness"
        printf "\n"
        ;;
    up)
        CUR=$(cat "${SYS_DIR}/brightness")
        NEW=$((CUR + STEP))
        [ "${NEW}" -gt "${MAX}" ] && NEW="${MAX}"
        printf "BRIGHTNESSUP detected: "
        if [ "${NEW}" -eq "${MAX}" ]; then
            printf "Screen brightness is as high as possible."
        else
            printf "Changing brightness from %s to %s." "${CUR}" "${NEW}"
        fi
        echo "${NEW}" > "${SYS_DIR}/brightness"
        printf "\n"
        ;;
    *)
        exit 1
        ;;

esac

exit 0
