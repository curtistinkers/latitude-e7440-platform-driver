#!/bin/sh
set -eu

RUN_DIR="/run/latitude-e7440-platform-driver"
BACKLIGHT_DIR="/sys/class/backlight/intel_backlight"
SAVE_FILE="${RUN_DIR}/power_brightness_save"

MAX_BRIGHT=$(cat "${BACKLIGHT_DIR}/max_brightness")
CUR_BRIGHT=$(cat "${BACKLIGHT_DIR}/brightness")

DIM_TARGET=$((MAX_BRIGHT * 30 / 100))

if [ ! -d "${RUN_DIR}" ]; then
    mkdir --mode=0700 "${RUN_DIR}"
fi

case "${1}" in
    battery)
        # Unplugged (OB): Only touch the screen if it is currently brighter than 30%
        if [ "${CUR_BRIGHT}" -gt "${DIM_TARGET}" ]; then
            if [ ! -f "${SAVE_FILE}" ]; then
                echo "${CUR_BRIGHT}" > "${SAVE_FILE}"
            fi
            echo "${DIM_TARGET}" > "${BACKLIGHT_DIR}/brightness"
        else
            # If it's already below 30%, do not brighten it, and clear any old state files
            rm -f "${SAVE_FILE}"
        fi
        ;;
    mains)
        # Plugged In (OL): Restore previous state if a save file exists, otherwise go to max
        if [ -f "${SAVE_FILE}" ]; then
            RESTORED=$(cat "${SAVE_FILE}")
            echo "${RESTORED}" > "${BACKLIGHT_DIR}/brightness"
            rm -f "${SAVE_FILE}"
        else
            # Only force max brightness if it was actually sitting exactly at our dim target
            if [ "${CUR_BRIGHT}" -eq "${DIM_TARGET}" ]; then
                echo "${MAX_BRIGHT}" > "${BACKLIGHT_DIR}/brightness"
            fi
        fi
        ;;
    *)
        exit 0
        ;;
esac

exit 0
