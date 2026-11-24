#!/bin/sh
set -eu

RUN_DIR="/run/latitude-e7440-platform-driver"
SAVE_FILE="${RUN_DIR}/lid_switch_brightness_save"
BACKLIGHT_DIR="/sys/class/backlight/intel_backlight"

if [ ! -d "${RUN_DIR}" ]; then
    mkdir --mode=0700 "${RUN_DIR}"
fi

case "${1}" in
    close)
        if [ ! -f "${SAVE_FILE}" ]; then
            CUR=$(cat "${BACKLIGHT_DIR}/brightness")
            printf "Lid CLOSED: Saving current brightness (%s) and setting screen to 0.\n" "${CUR}"
            cat "${BACKLIGHT_DIR}/brightness" > "${SAVE_FILE}"
            echo 0 > "${BACKLIGHT_DIR}/brightness"
        fi
        ;;
    open)
        if [ -f "${SAVE_FILE}" ]; then
            RESTORED=$(cat "${SAVE_FILE}")
            printf "Lid OPENNED: Restoring screen brightness to %s.\n" "${RESTORED}"
            cat "${SAVE_FILE}" > "${BACKLIGHT_DIR}/brightness"
            rm -f "${SAVE_FILE}"
        fi
        ;;
esac
