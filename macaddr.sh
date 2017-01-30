#!/bin/bash

set -eu

for arg in $(</proc/cmdline); do
    case "$arg" in
    smsc95xx.macaddr=*)
        install -d /run/systemd/network
        cat > /run/systemd/network/00-rpi3.link << EOF
[Match]
Driver=smsc95xx
Path=platform-3f980000.usb-usb-0:1.1:1.0

[Link]
MACAddress=${arg#smsc95xx.macaddr=}
EOF
        ;;
    esac
done
