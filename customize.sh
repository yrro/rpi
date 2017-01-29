#!/bin/bash

set -eux

rootdir="$1"
image="$2"

# If debootstrap installs this then it incorrectly insists on installing
# systemd-shim which conflicts with systemd-sysv
# Ok, we can't install package here because we have no networking. FFS.
#chroot "$rootdir" apt -qy install libpam-systemd

# apt clean is already run for us by vmdebootstrap
rm -vf "$rootdir/var/lib/apt/lists/{*_Index,*_Release,*_InRelease,*_Packages,*_Translation-*,*.gpg,*.gz,*.lz4}"

#echo overlay >> "$rootdir/etc/initramfs-tools/modules"
cat > "$rootdir/etc/initramfs-tools/hooks/root-overlay" <<- EOF
	#!/bin/bash

	. /usr/share/initramfs-tools/hook-functions

	force_load overlay
EOF
chmod 0755 "$rootdir/etc/initramfs-tools/hooks/root-overlay"

cat > "$rootdir/etc/initramfs-tools/scripts/init-bottom/root-overlay" <<- EOF
	#!/bin/sh

	case "\$1" in
	prereqs)
		exit 0
		;;
	esac

	. /scripts/functions

	if ! (mkdir /overlay && mount -t tmpfs none /overlay); then
		log_failure_msg 'Unable to prepare /overlay tmpfs'
		exit 0
	fi
	for d in upper work lower; do
		if ! mkdir "/overlay/\$d"; then
			log_failure_msg 'Unable to create /overlay tmpfs subdirs'
			exit 0
		fi
	done

	if ! mount -n -o move "\$rootmnt" /overlay/lower; then
		log_failure_msg 'Unable to move root fs mount to overlay filesystem'
		exit 0
	fi
	if ! mount -t overlay none -olowerdir=/overlay/lower,upperdir=/overlay/upper,workdir=/overlay/work "\$rootmnt"; then
		log_failure_msg 'Unable to create overlay filesystem'
		exit 0
	fi

	awk -- '
		\$2 == "/" { print "none", "/", "none", "rw", "0", "0" }
		\$2 != "/" { print \$0 }
		' "\$rootmnt/etc/fstab" > "\$rootmnt/etc/fstab.tmp"
	mv "\$rootmnt/etc/fstab.tmp" "\$rootmnt/etc/fstab"

	if ! (mkdir -p "\$rootmnt/overlay" && mount -n -o rbind /overlay "\$rootmnt/overlay"); then
		log_failure_msg 'Unable to make overlay tmpfs available within overlay filesystem'
	fi

	log_warning_msg '/etc/fstab not (yet) fixed up... problem?'

	exit 0
EOF
chmod 0755 "$rootdir/etc/initramfs-tools/scripts/init-bottom/root-overlay"

mkdir -p "$rootdir/etc/initramfs/post-update.d"
cat > "$rootdir/etc/initramfs/post-update.d/raspi3-firmware" <<- EOF
	#!/bin/bash
	set -eu
	VER="\$1"
	INITRAMFS="\$2"
	if mountpoint -q /boot/firmware; then
		cp "\$INITRAMFS" /boot/firmware
	else
		echo 'Warning: /boot/firmware is not mounted; firmware will boot using the old initramfs' >&2
		exit 0
	fi
EOF
chmod 0755 "$rootdir/etc/initramfs/post-update.d/raspi3-firmware"

gawk -i inplace '
	$2 == "/" { print $1, $2, $3, "ro," $4, "0", "0" }
	$2 == "/boot" { print $1, "/boot/firmware", $3, "ro,nofail," $4, "0", "0" }
	' \
	"$rootdir/etc/fstab"

sed -E -i 's/\s+\<rpi3\>//' "$rootdir/etc/hosts"
