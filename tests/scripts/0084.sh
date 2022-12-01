#!/bin/bash
#
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Copyright (C) 2019 Western Digital Corporation or its affiliates.
#

. scripts/test_lib

if [ $# == 0 ]; then
	echo "Files owner (user set value)"
        exit 0
fi

echo "Check for files UID/GID persistence"

zonefs_mkfs "$1"
zonefs_mount "$1"

if [ "$nr_cnv_files" != 0 ]; then
	check_file_uid_gid "$zonefs_mntdir/cnv/0" "0 0"
	chown 1000:1000 "$zonefs_mntdir"/cnv/0
	check_file_uid_gid "$zonefs_mntdir/cnv/0" "1000 1000"

	# Drop inode cache and check again
	drop_inode_cache
	check_file_uid_gid "$zonefs_mntdir/cnv/0" "1000 1000"
fi

check_file_uid_gid "$zonefs_mntdir/seq/0" "0 0"
chown 1000:1000 "$zonefs_mntdir"/seq/0
check_file_uid_gid "$zonefs_mntdir/seq/0" "1000 1000"

# Drop inode cache and check again
drop_inode_cache
check_file_uid_gid "$zonefs_mntdir/seq/0" "1000 1000"

zonefs_umount

exit 0
