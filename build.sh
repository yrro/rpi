#!/bin/bash

set -eu

rm -f debootstrap.log vmdebootstrap.log

vmdebootstrap \
	--arch arm64 \
	--distribution stretch \
	--mirror http://deb.debian.org/debian \
	--debootstrapopts 'variant=minbase components=main,contrib,non-free merged-usr' \
	--package raspi3-firmware \
	--image rpi3.img \
	--size 1024M \
	--bootsize 128M \
	--boottype vfat \
	--bootdirfmt=%s/boot/firmware \
	--log=vmdebootstrap.log \
	--verbose \
	--no-extlinux \
	--no-use-uefi \
	--root-password raspberry \
	--hostname rpi3 \
	--foreign /usr/bin/qemu-aarch64-static \
	--no-kernel --custom-package=linux-image-4.8.0-1-arm64-unsigned_4.8.7-1a~test_arm64.deb \
	--package init \
	--package systemd-sysv \
	--package libnss-resolve \
	--package dbus \
	--package openssh-server \
	--package netbase \
	--package less \
	--package iproute \
	--package vim-tiny \
	--package htop \
	--package prometheus-node-exporter \
	--custom-package ../igd-exporter/prometheus-igd-exporter_0+ga192588_all.deb \
	--customize "$PWD/customize.sh"
