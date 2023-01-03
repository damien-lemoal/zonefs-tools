#!/bin/bash
#
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Copyright (C) 2019 Western Digital Corporation or its affiliates.
#

. scripts/test_lib

if [ $# == 0 ]; then
	echo "Sequential file dsync write (async)"
        exit 0
fi

echo "Check sequential file dsync write (async)"

zonefs_mkfs "$1"
zonefs_mount "$1"

# Check with O_DSYNC file open
echo "Check async writes with O_DSYNC"

tools/zio --write --fflag=direct --fflag=dsync --async=8 \
	--size=$((2 * 1024 * 1024 )) "$zonefs_mntdir"/seq/0 || \
	exit_failed " --> FAILED"

sz=$(file_size "$zonefs_mntdir"/seq/0)
[ "$sz" != "$seq_file_0_max_size" ] && \
	exit_failed " --> Invalid file size $sz B, expected $seq_file_0_max_size B"

# Test with RWF_DSYNC I/O flag
echo "Check writes with RWF_APPEND"

truncate --no-create --size=0 "$zonefs_mntdir"/seq/0 || \
        exit_failed " --> FAILED"

tools/zio --write --fflag=direct --ioflag=dsync --async=8 \
	--size=$((2 * 1024 * 1024 )) "$zonefs_mntdir"/seq/0 || \
	exit_failed " --> FAILED"

sz=$(file_size "$zonefs_mntdir"/seq/0)
[ "$sz" != "$seq_file_0_max_size" ] && \
	exit_failed " --> Invalid file size $sz B, expected $seq_file_0_max_size B"

zonefs_umount

exit 0
