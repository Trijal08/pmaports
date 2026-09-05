#!/bin/sh
set -eu

VAR_DIR="/var/lib/pixel-modem"
FW_ROOT="${VAR_DIR}/firmware"
SYS_FW="/lib/firmware"

mkdir -p "$VAR_DIR" "$FW_ROOT"

SLOT=$(sed -n 's/.*androidboot.slot_suffix=_\([ab]\).*/\1/p' /proc/cmdline)
SLOT=${SLOT:-a}

dev() {
	echo "/dev/disk/by-partlabel/$1"
}

# Mount vendor extent dynamically from super if required
if ! mountpoint -q "${FW_ROOT}/vendor"; then
	read -r start sectors <<EOF
$(lpdump "$(dev super)" | awk '/^  Name: vendor_'"$SLOT"'$/ { f = 1; next } f && /linear super/ { print $NF, $3 - $1 + 1; exit }')
EOF
	[ -n "${start:-}" ] || { echo "ERROR: vendor_$SLOT not found in super" >&2; exit 1; }

	mkdir -p "${FW_ROOT}/vendor"
	offset=$((start * 512))
	limit=$((sectors * 512))

	# `losetup -j` is a query; --sizelimit is only accepted while *setting up* a
	# loop device, so passing it here made the whole command fail and print
	# "the options --{sizelimit,partscan,read-only,show} are allowed during loop
	# device setup only" on every boot. Match on the offset losetup reports
	# instead -- that identifies the extent without asking it to configure one.
	lo=$(losetup -j "$(dev super)" | sed -n "s|^\([^:]*\):.*offset $offset\(,.*\)\?$|\1|p" | head -n1)
	if [ -z "$lo" ]; then
		lo=$(losetup -f --show -r -o "$offset" --sizelimit "$limit" "$(dev super)")
	fi
	mount -o ro "$lo" "${FW_ROOT}/vendor"
fi

# Stage modem image and setup system firmware link
dd if="$(dev modem_$SLOT)" of="${VAR_DIR}/modem.bin" bs=4M status=none
mkdir -p "${SYS_FW}/exynos/s5400"
ln -sf "${VAR_DIR}/modem.bin" "${SYS_FW}/exynos/s5400/modem.bin"

if [ -w /sys/module/firmware_class/parameters/path ]; then
	echo -n "${SYS_FW}" > /sys/module/firmware_class/parameters/path
fi
