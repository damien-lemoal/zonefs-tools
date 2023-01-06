#!/bin/bash
#
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Copyright (C) 2023 Western Digital Corporation or its affiliates.
#

. scripts/test_lib

if [ $# == 0 ]; then
	echo "Sequential file offline zone (errors=zone-offline, io-err)"
        exit 0
fi

echo "Check sequential file on an offline zone at io-error time"

require_nullb_offline

nulldev=$(create_zoned_nullb)
dev="/dev/nullb${nulldev}"

zonefs_mkfs "${dev}"
zonefs_mount "-o errors=zone-offline ${dev}"

# Writing should be OK
echo "Write seq file 0"
write_file "${zonefs_mntdir}/seq/0" 4096

# Set the first seq file zone offline
set_nullb_first_seq_zone_offline ${nulldev}

# Writing should now fail
echo "Try writing seq file 0"
write_file_err "${zonefs_mntdir}/seq/0" 4096 0

# The file permission must have changed and the file size should be 0.
# The fs should be writable
echo "Check file size and permissions"
check_file_size "${zonefs_mntdir}/seq/0" 0
check_file_perm "${zonefs_mntdir}/seq/0" "000"
check_fs_is_writable

# Evicting the inode should not change anything
echo "Check file size and permissions after eviction"
drop_inode_cache
check_file_size "${zonefs_mntdir}/seq/0" 0
check_file_perm "${zonefs_mntdir}/seq/0" "000"

# We should be able to write another file
echo "Write seq file 1"
write_file "${zonefs_mntdir}/seq/1" 4096

zonefs_umount

destroy_nullb ${nulldev}

exit 0
