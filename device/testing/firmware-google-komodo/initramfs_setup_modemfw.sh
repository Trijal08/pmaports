#!/bin/sh
# Universal single-stage initramfs hook for Google Caimito Modem Firmware
#
# Mounts the vendor modem partitions, then stages the three files the
# s5xxx_modem driver expects under fixed names.  The driver deliberately parses
# nothing itself -- no CDT parse, no JSON, no gunzip, no tar builder -- so the
# resolution, decompression and packing all happen here:
#
#   google/s5400/hwcfg.bin          52-byte digest of the resolved HW/RF ids
#   google/s5400/rf_cfg.bin         this unit's RF_CFG image, decompressed
#   google/s5400/replay_region.bin  replay archive packed from the live dds.bin
#
# The replay archive carries an mtime and MAIN REJECTS A STALE ONE (it reaches
# ONLINE and then self-disables a few seconds later without ever servicing the
# IPC rings), which is why it is repacked here on every boot rather than shipped
# in the package.
set -e

FW=/sysroot/lib/firmware/google/s5400

echo "Initializing early-boot modem storage mounts..."

# 1. Create target directories directly on the persistent storage rootfs
mkdir -p "$FW/modem" "$FW/modem_userdata" "$FW/efs" "$FW/persist"

# 2. Mount each hardware partition directly into the /sysroot path
# These will stay cleanly mounted and transfer straight over to the running OS
mount -t ext4 /dev/disk/by-partlabel/modem_a "$FW/modem" -o ro,nodev,nosuid
mount -t f2fs /dev/disk/by-partlabel/modem_userdata "$FW/modem_userdata" -o ro,nodev,nosuid
mount -t f2fs /dev/disk/by-partlabel/efs "$FW/efs" -o ro,nodev,nosuid
mount -t f2fs /dev/disk/by-partlabel/persist "$FW/persist" -o ro,nodev,nosuid

IMAGES="$FW/modem/images/default"
JSON="$IMAGES/hardware_config.json"
DDS="$FW/modem_userdata/replay/dds.bin"

# Emit a little-endian u32.  Build the escape string first, then print it --
# command substitution would strip literal NUL bytes.
put_le32() {
	printf "$(printf '\\%03o\\%03o\\%03o\\%03o' \
		$(( $1        & 255)) \
		$(( ($1 >>  8) & 255)) \
		$(( ($1 >> 16) & 255)) \
		$(( ($1 >> 24) & 255)))"
}

# ---------------------------------------------------------------------------
# hwcfg.bin + rf_cfg.bin -- resolve this unit against the vendor config table
# ---------------------------------------------------------------------------
CDT=$(sed -n 's/.*androidboot\.cdt_hwid = "0x\([0-9a-fA-F]*\)".*/\1/p' /proc/bootconfig)

if [ -n "$CDT" ] && [ -r "$JSON" ]; then
	# androidboot.cdt_hwid packs fixed-width hex nibbles (vendor cbd
	# scan_cdt_property_data); the trailing 8 are vestigial.
	h() { printf '%d' "0x$(echo "$CDT" | cut -c"$1"-"$2")"; }
	PLATFORM=$(h 1 4);   PRODUCT=$(h 5 6);    BOARD=$(h 7 8)
	MAJOR=$(h 9 12);     MINOR=$(h 13 14);    VARIANT=$(h 15 16)
	RF_SKU=$(h 17 18);   MODEM_HW=$(h 19 20); RF_SUB=$(h 21 24)

	# Pick the configurations[] entry by (platform, product), then the
	# config_table row by the remaining identifiers -- same as vendor cbd.
	# Target vars are w-prefixed: an awk builtin (e.g. RS = record separator)
	# would otherwise wreck the parse.  Compare with +0 to force numeric.
	ROW=$(awk -v wplat="$PLATFORM" -v wprod="$PRODUCT" -v wstage="$BOARD" \
		  -v wmajor="$MAJOR" -v wminor="$MINOR" -v wsku="$RF_SKU" \
		  -v wmhw="$MODEM_HW" -v wsub="$RF_SUB" '
		function num(s) { gsub(/[^0-9]/, "", s); return s + 0 }
		/"platform"/    { p = num($0) }
		/"product"/     { pr = num($0) }
		/"config_file"/ { cf = $0
				  sub(/.*"config_file"[^"]*"/, "", cf)
				  sub(/".*/, "", cf) }
		/"stage"/       { st = num($0) }
		/"major"/       { mj = num($0) }
		/"minor"/       { mn = num($0) }
		/"rf_sub"/      { rs = num($0) }
		/"rf_sku"/      { rk = num($0) }
		/"rfid"/        { rid = num($0) }
		/"hwinfo"/      { hw = num($0) }
		/"modem_hw"/    { mh = num($0)
				  if (p == wplat+0 && pr == wprod+0 && st == wstage+0 &&
				      mj == wmajor+0 && mn == wminor+0 && rs == wsub+0 &&
				      rk == wsku+0 && mh == wmhw+0) {
					  print cf, rid, hw
					  exit
				  } }
	' "$JSON")

	if [ -n "$ROW" ]; then
		RF_FILE=${ROW%% *}; REST=${ROW#* }
		RFID=${REST%% *};   HWINFO=${REST#* }
		RF_FILE=${RF_FILE##*/}	# config_file is an absolute vendor path
		echo "Modem: cdt_hwid -> rfid=$RFID hwinfo=$HWINFO $RF_FILE"

		# struct s5300_hwcfg: magic "S5HW", version, 11 identifiers.
		{
			put_le32 $((0x57483553))	# magic "S5HW"
			put_le32 1		# version
			put_le32 "$PLATFORM"
			put_le32 "$HWINFO"	# revision
			put_le32 "$MAJOR"
			put_le32 "$MINOR"
			put_le32 "$RF_SKU"
			put_le32 "$MODEM_HW"
			put_le32 "$RF_SUB"
			put_le32 "$RFID"	# rf_config
			put_le32 "$PRODUCT"
			put_le32 "$BOARD"
			put_le32 "$VARIANT"
		} > "$FW/hwcfg.bin"

		# config_file has no suffix but the partition ships RF_CFG_*.gz;
		# the firmware loader only auto-decompresses xz/zstd, so normalise
		# to raw here.  Accept either the .gz or a raw drop-in.
		if [ -r "$IMAGES/$RF_FILE.gz" ]; then
			gunzip -c "$IMAGES/$RF_FILE.gz" > "$FW/rf_cfg.bin"
		elif [ -r "$IMAGES/$RF_FILE" ]; then
			if [ "$(od -An -tx1 -N2 "$IMAGES/$RF_FILE" | tr -d ' ')" = "1f8b" ]; then
				gunzip -c "$IMAGES/$RF_FILE" > "$FW/rf_cfg.bin"
			else
				cp "$IMAGES/$RF_FILE" "$FW/rf_cfg.bin"
			fi
		else
			echo "Modem: WARNING $RF_FILE(.gz) missing; rf_cfg.bin not staged"
		fi
	else
		echo "Modem: WARNING no config_table row matches this cdt_hwid"
	fi
else
	echo "Modem: WARNING cdt_hwid or hardware_config.json unavailable"
fi

# ---------------------------------------------------------------------------
# replay_region.bin -- repack the LIVE dds.bin on every boot.  One GNU-tar
# member, byte-for-byte as the vendor cbd builds it.  busybox tar cannot set
# owner/mode/mtime (and --format=ustar would emit the wrong "ustar\0" magic --
# MAIN wants GNU's "ustar  \0"), so write the 512-byte header by hand.
# ---------------------------------------------------------------------------
REPLAY_SIZE=524288

if [ -r "$DDS" ]; then
	SZ=$(wc -c < "$DDS")
	if [ "$SZ" -le $((REPLAY_SIZE - 1536)) ]; then
		HDR=$(mktemp)
		dd if=/dev/zero of="$HDR" bs=512 count=1 2>/dev/null

		# Header is pre-zeroed, so each field's trailing NUL comes for free.
		w() { printf '%s' "$2" | dd of="$HDR" bs=1 seek="$1" conv=notrunc 2>/dev/null; }
		w 0   'replay/dds.bin'				# name[100]
		w 100 '0000666'					# mode
		w 108 '0001751'					# uid 1001 (radio)
		w 116 '0001750'					# gid 1000 (system)
		w 124 "$(printf '%011o' "$SZ")"			# size
		w 136 "$(printf '%011o' "$(date +%s)")"		# mtime -- must be fresh
		w 148 '        '				# chksum: spaces while summing
		w 156 '0'					# typeflag: regular file
		w 257 'ustar  '					# magic+version "ustar  \0"
		w 265 'radio'					# uname
		w 297 'system'					# gname

		SUM=$(od -An -tu1 -v "$HDR" |
		      awk '{ for (i = 1; i <= NF; i++) s += $i } END { print s }')
		w 148 "$(printf '%06o' "$SUM")"			# 6 octal digits ...
		dd if=/dev/zero of="$HDR" bs=1 seek=154 count=1 conv=notrunc 2>/dev/null
		w 155 ' '					# ... NUL at [154], space at [155]

		cat "$HDR" "$DDS" > "$FW/replay_region.bin"
		rm -f "$HDR"

		# zero-pad to the TOC section size
		CUR=$(wc -c < "$FW/replay_region.bin")
		dd if=/dev/zero bs=1 count=$((REPLAY_SIZE - CUR)) \
			>> "$FW/replay_region.bin" 2>/dev/null
		echo "Modem: replay_region.bin repacked (dds.bin $SZ bytes)"
	else
		echo "Modem: WARNING dds.bin too large ($SZ); replay not staged"
	fi
else
	echo "Modem: WARNING $DDS missing; replay_region.bin not staged"
fi

echo "Modem setup complete. Proceeding to switch_root."
