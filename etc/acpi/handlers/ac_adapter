#!/bin/sh
set -eu

case "${4}" in
    00000000)
        # Battery power
        /usr/libexec/latitude-e7440-platform-driver/ac-adapter-handler.sh battery
        ;;
    00000001)
        # Mains power
        /usr/libexec/latitude-e7440-platform-driver/ac-adapter-handler.sh mains
        ;;
    *)
        exit 1
        ;;
esac

exit 0
