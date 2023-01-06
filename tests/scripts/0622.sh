#!/bin/bash
#
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Copyright (C) 2023 Western Digital Corporation or its affiliates.
#

. scripts/test_lib

if [ $# == 0 ]; then
	echo "Sequential file offline zone (errors=zone-ro, mount)"
        exit 0
fi

echo "Check sequential file on an offline zone at mount time"

require_nullb_offline

nulldev=$(create_zoned_nullb)
dev="/dev/nullb${nulldev}"

zonefs_mkfs "${dev}"
zonefs_mount "${dev}"

# Writing should be OK
echo "Write seq file 0"
write_file "${zonefs_mntdir}/seq/0" 4096

# Unmount, set the first seq file zone offline and remount
echo "Remounting FS with seq file 0 zone as offline"
zonefs_umount "${dev}"
set_nullb_first_seq_zone_offline "${nulldev}"
zonefs_mount "-o errors=zone-ro ${dev}"

# The file permission must have changed and the file size should be 0.
# The fs should be writable
echo "Check file size and permissions"
check_file_size "${zonefs_mntdir}/seq/0" 0
check_file_perm "${zonefs_mntdir}/seq/0" "000"
check_fs_is_writable

# Writing to the file should fail
echo "Try writing readonly seq file 0"
write_file_err "${zonefs_mntdir}/seq/0" 4096 0

# We should be able to write another file
echo "Write seq file 1"
write_file "${zonefs_mntdir}/seq/1" 4096

zonefs_umount

destroy_nullb ${nulldev}

exit 0
