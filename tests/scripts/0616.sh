#!/bin/bash
#
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Copyright (C) 2023 Western Digital Corporation or its affiliates.
#

. scripts/test_lib

if [ $# == 0 ]; then
	echo "Sequential file readonly zone (errors=repair, mount)"
        exit 0
fi

echo "Check sequential file on a read-only zone at mount time"

require_nullb_readonly

nulldev=$(create_zoned_nullb)
dev="/dev/nullb${nulldev}"

zonefs_mkfs "${dev}"
zonefs_mount "${dev}"

# Writing should be OK
echo "Write seq file 0"
write_file "${zonefs_mntdir}/seq/0" 4096

# Unmount, set the first seq file zone readonly and remount
echo "Remounting FS with seq file 0 zone as read-only"
zonefs_umount "${dev}"
set_nullb_first_seq_zone_readonly "${nulldev}"
zonefs_mount "-o errors=repair ${dev}"

# The file permission must have changed and the file size should be 0.
# The fs should be writable
echo "Check file size and permissions"
check_file_size "${zonefs_mntdir}/seq/0" 0
check_file_perm "${zonefs_mntdir}/seq/0" "000"
check_fs_is_writable

# Writing to he readonly file should fail
echo "Try writing readonly seq file 0"
write_file_err "${zonefs_mntdir}/seq/0" 4096 0

# We should be able to write another file
echo "Write seq file 1"
write_file "${zonefs_mntdir}/seq/1" 4096

zonefs_umount

destroy_nullb ${nulldev}

exit 0
