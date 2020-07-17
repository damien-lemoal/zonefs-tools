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

dd if=/dev/zero of="$zonefs_mntdir"/seq/0 oflag=direct bs=4096 count=1 || \
	exit_failed " --> FAILED"

sz=$(file_size "$zonefs_mntdir"/seq/0)
[ "$sz" != "4096" ] && \
	exit_failed " --> Invalid file size $sz B, expected 4096 B"

dd if=/dev/zero of="$zonefs_mntdir"/seq/0 oflag=direct,append bs=4096 \
	count=$(( seq_file_0_max_size / 4096 - 1)) conv=notrunc || \
	exit_failed " --> FAILED"

sz=$(file_size "$zonefs_mntdir"/seq/0)
[ "$sz" != "$seq_file_0_max_size" ] && \
	exit_failed " --> Invalid file size $sz B, expected $seq_file_0_max_size B"

zonefs_umount

exit 0
