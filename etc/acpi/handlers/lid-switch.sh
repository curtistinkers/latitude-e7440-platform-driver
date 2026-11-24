#!/bin/sh
set -eu

case "${3}" in
    close)
        /usr/libexec/latitude-e7440-platform-driver/lid-switch-handler.sh close
        ;;
    open)
        /usr/libexec/latitude-e7440-platform-driver/lid-switch-handler.sh open
        ;;
    *)
        exit 1
        ;;
esac

exit 0
