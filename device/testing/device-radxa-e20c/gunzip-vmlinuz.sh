#!/bin/sh

# Rockchip u-boot does not support compressed kernels. Boot-deploy hook makes
# sure it is gunzipped
if (file /boot/vmlinuz | grep -q gzip ) ; then
	echo "Kernel is compressed! Rockchip u-boot does not support compressed kernels. Decompressing..."
	mv /boot/vmlinuz /boot/vmlinuz.gz
	gunzip /boot/vmlinuz.gz
fi
