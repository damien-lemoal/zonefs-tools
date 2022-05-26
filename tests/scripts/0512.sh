#!/bin/bash
#
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Copyright (C) 2022 Western Digital Corporation or its affiliates.
#

. scripts/test_lib

if [ $# == 0 ]; then
	echo "Sysfs seq files active after mount (active zones)"
        exit 0
fi

require_sysfs

# Check that the number of active files matches the number of
# active zones.
zonefs_mkfs "$1"

i=0
nract=$(get_max_open_zones "$1")
if [ ${nract} -eq 0 ]; then
	nract=4
fi

echo "Writing 4K in ${nract} zones"

for((i=1; i<=${nract}; i++)); do
	zstart=$(( (nr_cnv_zones + i) * zone_bytes / 4096 ))
	dd if=/dev/zero of="$1" bs=4096 seek=${zstart} count=1 oflag=direct ||
		exit_failed "write seq zone failed"
done

echo "Check active seq files count"

zonefs_mount "$1"

sysfs_val=$(sysfs_nr_active_seq_files "$1")
[[ ${sysfs_val} -eq ${nract} ]] || \
	exit_failed "nr_active_seq_files is ${sysfs_val} (should be 4)"

zonefs_umount

exit 0
