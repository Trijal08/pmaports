#!/bin/sh
# Claim the tail of the boot medium for a separate STORAGE partition.
#
# pmbootstrap cannot express this: pmb/install/partition.py hardcodes
#
#	commands += [["mkpart", "primary", mb_root_start, "100%"]]
#
# and deviceinfo has no key for extra partitions, so the layout is always
# boot + root and root always takes everything. The only place left to do it
# is here. init_2nd.sh runs /hooks-extra after udev has settled but before
# wait_root_partition, resize_root_partition and mount_root_partition, so the
# table can be edited while nothing is mounted.
#
# Order matters: by taking the free space now, has_unallocated_space() is
# false when the stock resize runs a moment later, so root is left at the
# size set here instead of swallowing the card. Nothing is shrunk - if the
# image's root is already larger than the target it is kept as-is - and the
# whole thing is a no-op once partition 3 exists.
#
# Formatting is deliberately not done here: mkfs.exfat is not in the
# initramfs, so storage-partition.service does it on the first real boot.

ROOT_SIZE_MIB=8192
ALIGN=$((1024 * 1024))

info() { echo "storage-partition: $*"; }

root_part="$(blkid --label pmOS_root 2>/dev/null)"
if [ -z "$root_part" ]; then
	info "no pmOS_root partition found, skipping"
	exit 0
fi

# /dev/mmcblk0p2 -> /dev/mmcblk0, /dev/sda2 -> /dev/sda
disk="$(echo "$root_part" | sed -E 's/p?[0-9]+$//')"
if [ ! -b "$disk" ]; then
	info "$disk is not a block device, skipping"
	exit 0
fi

if parted -ms "$disk" unit B print 2>/dev/null | grep -q '^3:'; then
	info "partition 3 already exists, nothing to do"
	exit 0
fi

# Same test resize_root_partition() uses, for the same reason.
if ! parted -s "$disk" print free 2>/dev/null | tail -n2 | head -n1 |
		grep -qi "free space"; then
	info "no unallocated space, nothing to do"
	exit 0
fi

for arg in $(cat /proc/cmdline); do
	case "$arg" in
		pmos_root_size=*) ROOT_SIZE_MIB="${arg#*=}" ;;
	esac
done

table="$(parted -ms "$disk" unit B print 2>/dev/null)"
disk_size="$(echo "$table" | sed -n '2p' | cut -d: -f2)"
disk_size="${disk_size%B}"
root_line="$(echo "$table" | grep '^2:')"
root_start="$(echo "$root_line" | cut -d: -f2)"
root_start="${root_start%B}"
root_end="$(echo "$root_line" | cut -d: -f3)"
root_end="${root_end%B}"

case "$root_start$root_end$disk_size$ROOT_SIZE_MIB" in
	*[!0-9]*|"") info "could not parse the partition table, skipping"; exit 0 ;;
esac

# Round the boundary up to a 1 MiB alignment, and never move it backwards:
# shrinking a filesystem is out of scope here.
part3_start=$(( (root_start + ROOT_SIZE_MIB * ALIGN + ALIGN - 1) / ALIGN * ALIGN ))
if [ "$part3_start" -le "$root_end" ]; then
	part3_start=$(( (root_end + 1 + ALIGN - 1) / ALIGN * ALIGN ))
fi

# Not worth splitting the card for a sliver.
if [ $((disk_size - part3_start)) -lt $((512 * ALIGN)) ]; then
	info "less than 512 MiB would be left over, skipping"
	exit 0
fi

info "root ends at $((part3_start - 1))B, STORAGE takes the rest"

# -f: the backup GPT header is still where the flashed image left it, part
# way up the card, and parted refuses to touch the table until that is fixed.
if ! parted -f -s "$disk" unit B resizepart 2 "$((part3_start - 1))B"; then
	info "resizing root failed, leaving the table alone"
	exit 0
fi

# On GPT the first argument to mkpart is the partition name, which is what
# storage-partition.service looks the partition up by.
if ! parted -f -s "$disk" unit B mkpart storage "${part3_start}B" 100%; then
	info "creating the storage partition failed"
	exit 0
fi

partprobe "$disk" 2>/dev/null || blockdev --rereadpt "$disk" 2>/dev/null || true
udevadm settle 2>/dev/null || true

info "created $(parted -ms "$disk" unit B print | grep '^3:' || echo 'partition 3')"
