#!/bin/bash
#
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Copyright (C) 2023 Western Digital Corporation or its affiliates.
#

. scripts/test_lib

if [ $# == 0 ]; then
	echo "Sequential file readonly zone (errors=repair, io-err)"
        exit 0
fi

echo "Check sequential file on a read-only zone at io-error time"

require_nullb_readonly

nulldev=$(create_zoned_nullb)
dev="/dev/nullb${nulldev}"

zonefs_mkfs "${dev}"
zonefs_mount "-o errors=repair ${dev}"

# Writing should be OK
echo "Write seq file 0"
write_file "${zonefs_mntdir}/seq/0" 4096

# Set the first seq file zone readonly
set_nullb_first_seq_zone_readonly ${nulldev}

# Writing should now fail
echo "Try writing seq file 0"
write_file_err "${zonefs_mntdir}/seq/0" 4096 4096

# Truncate should also fail
echo "Try file truncate to 0 (zone reset)"
truncate_file "${zonefs_mntdir}/seq/0" 0 && \
	exit_failed " --> truncate SUCCESS (should FAIL)"
check_file_size "${zonefs_mntdir}/seq/0" 4096

# File permission should have changed and the file system should
# still be writable
echo "Check permissions"
check_file_perm "${zonefs_mntdir}/seq/0" "440"
check_fs_is_writable

# Evicting the inode should not change anything
echo "Check file size and permissions after eviction"
drop_inode_cache
check_file_size "${zonefs_mntdir}/seq/0" 4096
check_file_perm "${zonefs_mntdir}/seq/0" "440"

# We should be able to write another file
echo "Write seq file 1"
write_file "${zonefs_mntdir}/seq/1" 4096

zonefs_umount

destroy_nullb ${nulldev}

exit 0
