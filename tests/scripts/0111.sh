#!/bin/bash
#
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Copyright (C) 2023 Western Digital Corporation or its affiliates.
#

. scripts/test_lib

if [ $# == 0 ]; then
	echo "File names and inode numbers (aggr_cnv)"
        exit 0
fi

require_cnv_files

echo "Check file names and their inode numbers"

zonefs_mkfs "-o aggr_cnv $1"
zonefs_mount "$1"

echo "Checking root inode $zonefs_mntdir"
check_dir_ino "$zonefs_mntdir" ${nr_zones}

echo "Checking cnv directory inode number"
check_dir_ino "$zonefs_mntdir/cnv" $(( nr_zones + 1 ))

echo "Checking cnv directory files inode number"
check_files_ino "$zonefs_mntdir/cnv" ${nr_cnv_files} 1

if $short; then
	nrfiles=$(min ${nr_seq_files} 2000)
else
	nrfiles=${nr_seq_files}
fi

echo "Checking seq directory inode number"
check_dir_ino "$zonefs_mntdir/seq" $(( nr_zones + 2 ))

echo "Checking seq directory files inode number"
check_files_ino "$zonefs_mntdir/seq" \
	${nrfiles} \
	$(( seq_file_0_zone_start_sector / zone_sectors ))

zonefs_umount

exit 0
