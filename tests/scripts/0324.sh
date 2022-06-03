#!/bin/bash
#
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Copyright (C) 2022 Western Digital Corporation or its affiliates.
#

. scripts/test_lib

if [ $# == 0 ]; then
	echo "Sequential file readahead"
        exit 0
fi

echo "Check sequential file readahead"

zonefs_mkfs "$1"
zonefs_mount "$1"

bs=$(block_size "$zonefs_mntdir"/seq/0)

dd if=/dev/zero of="$zonefs_mntdir"/seq/0 oflag=direct bs="$bs" count=1 || \
	exit_failed " --> FAILED"

sz=$(file_size "$zonefs_mntdir"/seq/0)
[ "$sz" != "$bs" ] && \
	exit_failed " --> Invalid file size $sz B, expected $bs B"

dd if="$zonefs_mntdir"/seq/0 of=/dev/null bs="$bs" count=1 || \
	exit_failed " --> FAILED"

zonefs_umount

exit 0
