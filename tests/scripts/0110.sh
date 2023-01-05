#!/bin/bash
#
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Copyright (C) 2023 Western Digital Corporation or its affiliates.
#

. scripts/test_lib

if [ $# == 0 ]; then
	echo "File names and inode numbers (default)"
        exit 0
fi

echo "Check file names and their inode numbers"

zonefs_mkfs "$1"
zonefs_mount "$1"

echo "Checking root inode $zonefs_mntdir"
check_dir_ino "$zonefs_mntdir" ${nr_zones}

if [ "$nr_cnv_files" != "0" ]; then
	echo "Checking conventional files"

	if $short; then
		nrfiles=$(min ${nr_cnv_files} 500)
	else
		nrfiles=${nr_cnv_files}
	fi

	check_dir_ino "$zonefs_mntdir/cnv" $(( nr_zones + 1 ))
	check_files_ino "$zonefs_mntdir/cnv" ${nrfiles} 1
fi

echo "Checking sequential files"

if $short; then
	nrfiles=$(min ${nr_seq_files} 2000)
else
	nrfiles=${nr_seq_files}
fi

check_dir_ino "$zonefs_mntdir/seq" $(( nr_zones + 2 ))
check_files_ino "$zonefs_mntdir/seq" \
	${nrfiles} \
	$(( seq_file_0_zone_start_sector / zone_sectors ))

zonefs_umount

exit 0
