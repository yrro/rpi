#!/bin/bash

set -eux

rootdir="$1"
image="$2"

# If debootstrap installs this then it incorrectly insists on installing
# systemd-shim which conflicts with systemd-sysv
# Ok, we can't install package here because we have no networking. FFS.
#chroot "$rootdir" apt -qy install libpam-systemd

# apt clean is already run for us by vmdebootstrap
rm -f "$rootdir/var/lib/apt/lists/"*_*

# Use overlay mount for root filesystem
install -m 0755 -t "$rootdir/etc/initramfs-tools/hooks" initramfs-hooks/root-overlay
install -m 0755 -t "$rootdir/etc/initramfs-tools/scripts/local-bottom" initramfs-scripts/root-overlay

# Generate hostname from serial number
rm -f "$rootdir/etc/hostname"
sed -E -i 's/\s+\<rpi3\>//' "$rootdir/etc/hosts" # Resolution of hostname will be performed by nss-resolve(8)
install -m 0755 -t "$rootdir/etc/initramfs-tools/scripts/init-bottom" initramfs-scripts/rpi3-hostname

# Set up machine-id here to avoid triggering systemd empty_etc logic, that
# activates presets, resulting in weirdness like ssh.socket being enabled
rm -f "$rootdir/etc/machine-id"
rm -f "$rootdir/var/lib/dbus/machine-id"
install -m 0755 -t "$rootdir/etc/initramfs-tools/scripts/init-bottom" initramfs-scripts/rpi3-machine-id

# Mainline smsc95xx USB ethernet driver does not support the smsc95xx.macaddr
# kernel parameter, so use udev to change the MAC address based on the value
# passed by the boot loader.
install -m 0644 -D -t "$rootdir/etc/systemd/system/systemd-udevd.service.d" macaddr.conf
install -m 0755 -D -t "$rootdir/usr/local/lib/rpi3" macaddr.sh

# Copy generated initramfs to boot partition
install -m 0755 -D -t "$rootdir/etc/initramfs/post-update.d" raspi3-firmware

install -m 0644 -D -t "$rootdir/etc/systemd/system.conf.d" watchdog.conf

if [[ -f ssh.tar ]]; then
    rm -f "$rootdir/etc/ssh/"ssh_host_*_key{,.pub}
    tar -x -f ssh.tar -C "$rootdir/etc/ssh"
fi

if [[ -f tinc.tar ]]; then
    tar -x -f tinc.tar -C "$rootdir/etc/tinc"
    install -m 0644 -t "$rootdir/etc/systemd/network" robots.network
    chroot "$rootdir" systemctl enable tinc@robots.service
fi

install -m 0644 -t "$rootdir/etc" machine-info

install -m 0644 -t "$rootdir/etc/default" default/locale

# Remove unused entry for root filesystem and mount boot filesystem readonly
gawk -i inplace '
    $2 == "/" {}
    $2 == "/boot" { print $1, "/boot/firmware", $3, "ro,nofail," $4, "0", "0" }
    ' \
    "$rootdir/etc/fstab"

# Why isn't this the default?
chroot "$rootdir" systemctl enable prometheus-node-exporter.service

install -m 0644 -t "$rootdir/etc/prometheus" blackbox.yml
install -m 0644 -D -t "$rootdir/etc/systemd/system/prometheus-blackbox-exporter.service.d" allow-ping.conf
