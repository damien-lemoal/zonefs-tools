#!/bin/bash
#
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Copyright (C) 2023 Western Digital Corporation or its affiliates.
#

. scripts/test_lib

if [ $# == 0 ]; then
	echo "Sequential file readonly zone (errors=remount-ro, io-err)"
        exit 0
fi

echo "Check sequential file on a read-only zone at io-error time"

require_nullb_readonly

nulldev=$(create_zoned_nullb)
dev="/dev/nullb${nulldev}"

zonefs_mkfs "${dev}"
zonefs_mount "${dev}"

# Writing should be OK
echo "Write seq file 0"
write_file "${zonefs_mntdir}/seq/0" 4096

# Set the first seq file zone readonly
set_nullb_first_seq_zone_readonly "${nulldev}"

# Writing should now fail
echo "Try writing readonly seq file 0"
write_file_err "${zonefs_mntdir}/seq/0" 4096 4096

# Truncate should also fail
echo "Try file truncate to 0 (zone reset)"
truncate_file "${zonefs_mntdir}/seq/0" 0 && \
	exit_failed " --> truncate SUCCESS (should FAIL)"
check_file_size "${zonefs_mntdir}/seq/0" 4096

# File permission should have changed and the entire file system
# should now be read-only
echo "Check permissions"
check_file_perm "${zonefs_mntdir}/seq/0" "440"
check_fs_is_readonly

# Evicting the inode should not change anything
echo "Check file size and permissions after eviction"
drop_inode_cache
check_file_size "${zonefs_mntdir}/seq/0" 4096
check_file_perm "${zonefs_mntdir}/seq/0" "440"

# We should still be able to read the file
echo "Try reading seq file 0"
dd of=/dev/null if="${zonefs_mntdir}/seq/0" iflag=direct bs=4096 count=1 || \
	exit_failed " --> read FAILED"

# We should not be able to write another file
echo "Try writing seq file 1"
write_file_err "${zonefs_mntdir}/seq/1" 4096 0

zonefs_umount

destroy_nullb ${nulldev}

exit 0
