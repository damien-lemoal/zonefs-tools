#!/bin/bash
#
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Copyright (C) 2019 Western Digital Corporation or its affiliates.
#

. scripts/test_lib

if [ $# == 0 ]; then
	echo "Sequential file append (sync)"
        exit 0
fi

echo "Check sequential file append (sync)"

zonefs_mkfs "$1"
zonefs_mount "$1"

# Check with O_APPEND file open
echo "Check sync append writes with O_APPEND"

dd if=/dev/zero of="$zonefs_mntdir"/seq/0 oflag=direct bs=4096 count=1 || \
	exit_failed " --> FAILED"

sz=$(file_size "$zonefs_mntdir"/seq/0)
[ "$sz" != "4096" ] && \
	exit_failed " --> Invalid file size $sz B, expected 4096 B"

tools/zio --write --fflag=direct --fflag=append \
	--size=135168 "$zonefs_mntdir"/seq/0 || \
	exit_failed " --> FAILED"

sz=$(file_size "$zonefs_mntdir"/seq/0)
[ "$sz" != "$seq_file_0_max_size" ] && \
	exit_failed " --> Invalid file size $sz B, expected $seq_file_0_max_size B"

# Test with RWF_APPEND I/O flag
echo "Check sync append writes with RWF_APPEND"

truncate --no-create --size=0 "$zonefs_mntdir"/seq/0 || \
        exit_failed " --> FAILED"

dd if=/dev/zero of="$zonefs_mntdir"/seq/0 oflag=direct bs=4096 count=1 || \
	exit_failed " --> FAILED"

tools/zio --write --fflag=direct --ioflag=append \
	--size=135168 "$zonefs_mntdir"/seq/0 || \
	exit_failed " --> FAILED"

sz=$(file_size "$zonefs_mntdir"/seq/0)
[ "$sz" != "$seq_file_0_max_size" ] && \
	exit_failed " --> Invalid file size $sz B, expected $seq_file_0_max_size B"

zonefs_umount

exit 0
