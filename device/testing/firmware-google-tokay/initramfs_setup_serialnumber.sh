#!/bin/sh
# Universal single-stage initramfs hook for Google Pixel System Serial Injection
#
# Connects the bootloader's dynamic runtime hardware identifiers to the root
# device tree structures. The Linux virtual filesystem (sysfs) marks all nodes under
# /sys/firmware/devicetree/base as strictly read-only, preventing user-space tools
# from echoing text parameters into them directly.
#
# However, the Virtual File System (VFS) layer permits direct file-to-file bind
# mounts across pseudo-filesystems when executed during the initramfs stage. This hook
# maps the runtime Processor/Product Serial Number (PSN) directly onto the standard
# root 'serial-number' leaf node slot, ensuring compliance across all distributions:
#
#   /sys/firmware/devicetree/base/chosen/config/psn   ->  .../base/serial-number
#
# Because /proc/device-tree/ handles data redirection as a direct, transparent symlink
# to the primary sysfs base tree root directory, mapping the destination file property
# in sysfs automatically updates the procfs data arrays. Desktop managers and libraries
# like KDE Plasma (kinfocenter's about-distro module) will natively resolve the true
# hardware identifier through standard stream handlers, removing any service-manager
# configuration file dependencies.
set -e

echo "Initializing early-boot hardware serial mapping structures..."

BOOTLOADER_PSN="/sys/firmware/devicetree/base/chosen/config/psn"

# ---------------------------------------------------------------------------
# Devicetree Node Cross-Linking & Mount Layer Configuration
# ---------------------------------------------------------------------------

# 1. Block execution for up to 2 seconds to allow the kernel's hardware tree
# drivers to fully export the bootloader-populated chosen configuration blocks.
for i in $(seq 1 20); do
	[ -f "$BOOTLOADER_PSN" ] && break
	sleep 0.1
done

if [ -f "$BOOTLOADER_PSN" ]; then
	# 2. Determine the active target layout pathway. If the initramfs environment
	# has already executed its 'mount --move' lifecycle tasks to prepare the target
	# rootfs environment, we target /sysroot. Otherwise, we mount locally so the
	# bind tracking propagates forward during the subsequent system pivot.
	if [ -f "/sysroot/sys/firmware/devicetree/base/serial-number" ]; then
		TARGET_NODE="/sysroot/sys/firmware/devicetree/base/serial-number"
		echo "Hardware Serial: Target staging path detected inside /sysroot context."
	else
		TARGET_NODE="/sys/firmware/devicetree/base/serial-number"
		echo "Hardware Serial: Target staging path detected inside local initramfs context."
	fi

	# 3. Perform the VFS direct bind mount operation over the placeholder node.
	if [ -f "$TARGET_NODE" ]; then
		mount --bind "$BOOTLOADER_PSN" "$TARGET_NODE"
		echo "Hardware Serial: Successfully linked bootloader PSN to device tree master layer."
	else
		echo "Hardware Serial: WARNING target serial-number placeholder missing in DTS configuration layout."
	fi
else
	echo "Hardware Serial: WARNING bootloader PSN configuration node unavailable."
fi

echo "Hardware configuration complete. Proceeding to switch_root."
