#!/bin/bash
#
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Copyright (C) 2022 Western Digital Corporation or its affiliates.
#

. scripts/test_lib

if [ $# == 0 ]; then
	echo "Sysfs seq files active after mount (open zones)"
        exit 0
fi

require_sysfs

# Format and then write the first file seq zone to activate it
# (emulate an EPO event after a file was open)
zonefs_mkfs "$1"

zstart=$(( (nr_cnv_zones + 1) * zone_sectors ))
blkzone open -o ${zstart} -l ${zone_sectors} "$1" || \
	exit_failed "Explicit open zone failed"

echo "Check active seq files count"

zonefs_mount "$1"

sysfs_val=$(sysfs_nr_active_seq_files "$1")
[[ ${sysfs_val} -eq 0 ]] || \
	exit_failed "nr_active_seq_files is ${sysfs_val} (should be 0)"

zonefs_umount

exit 0
