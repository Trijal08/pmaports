#!/bin/sh -e
# Description: bootrr sanity check

mount -t debugfs debugfs /sys/kernel/debug

bootrr | tee bootrr.log

umount /sys/kernel/debug

if grep -q 'fail' bootrr.log; then
	echo "PMOS-CI-TEST: bootrr sanity check failed"
	exit 1
fi
