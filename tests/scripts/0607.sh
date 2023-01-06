#!/bin/bash
#
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Copyright (C) 2023 Western Digital Corporation or its affiliates.
#

. scripts/test_lib

if [ $# == 0 ]; then
	echo "Sequential file write IO error (errors=repair, async)"
        exit 0
fi

echo "Check handling of sequential file write IO error"

zonefs_mkfs "$1"
zonefs_mount "-o errors=repair $1"

# Writing should be OK
echo "Write seq file 0"
write_file "${zonefs_mntdir}/seq/0" 4096

# Move the zone write pointer without the FS knowing about it
echo "Write seq file 0 zone directly"
write_file_zone "$1" "${zonefs_mntdir}/seq/0"

# Now, writing should fail
echo "Try writing seq file 0"
write_file_async_err "${zonefs_mntdir}/seq/0" 4096 8192

# File permission should not have changed and the file system
# should still be usable
echo "Check permissions"
check_file_perm "${zonefs_mntdir}/seq/0" "640"
check_fs_is_writable

# Evicting the inode should not change anything
echo "Check file size and permissions after eviction"
drop_inode_cache
check_file_size "${zonefs_mntdir}/seq/0" 8192
check_file_perm "${zonefs_mntdir}/seq/0" "640"

# We should still be able to read the file
echo "Try reading seq file 0"
dd of=/dev/null if="${zonefs_mntdir}/seq/0" iflag=direct bs=4096 count=1 || \
	exit_failed " --> read FAILED"

# Truncate should be OK
echo "Try file truncate to 0 (zone reset)"
truncate_file "${zonefs_mntdir}/seq/0" 0 || \
	exit_failed " --> truncate FAILED"
check_file_size "${zonefs_mntdir}/seq/0" 0

# We should be able to write another file
echo "Try writing seq file 1"
write_file "${zonefs_mntdir}/seq/1" 4096 4096

zonefs_umount

exit 0
