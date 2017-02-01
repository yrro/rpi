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

# Mainline smsc95xx USB ethernet driver does not support the smsc95xx.macaddr
# kernel parameter, so use udev to change the MAC address based on the value
# passed by the boot loader.
install -m 0644 -D -t "$rootdir/etc/systemd/system/systemd-udevd.service.d" macaddr.conf
install -m 0755 -D -t "$rootdir/usr/local/lib/rpi3" macaddr.sh

# Copy generated initramfs to boot partition
install -m 0755 -D -t "$rootdir/etc/initramfs/post-update.d" raspi3-firmware

install -m 0644 -D -t "$rootdir/etc/systemd/system.conf.d/" watchdog.conf

tar -x -f tinc.tar -C "$rootdir/etc/tinc"
install -m 0644 -t "$rootdir/etc/systemd/network" robots.network
chroot "$rootdir" systemctl enable tinc@robots.service

# Remove unused entry for root filesystem and mount boot filesystem readonly
gawk -i inplace '
	$2 == "/" {}
	$2 == "/boot" { print $1, "/boot/firmware", $3, "ro,nofail," $4, "0", "0" }
	' \
	"$rootdir/etc/fstab"

# systemd will generate this for us
rm -f "$rootdir/etc/machine-id"
