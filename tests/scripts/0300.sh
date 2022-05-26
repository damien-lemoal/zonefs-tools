#!/bin/bash
#
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Copyright (C) 2019 Western Digital Corporation or its affiliates.
#

. scripts/test_lib

if [ $# == 0 ]; then
	echo "Sequential file truncate"
        exit 0
fi

echo "Check sequential file truncate"

zonefs_mkfs "$1"
zonefs_mount "$1"

dd if=/dev/zero of="$zonefs_mntdir"/seq/0 oflag=direct bs=4096 count=1 || \
	exit_failed " --> FAILED"

sz=$(file_size "$zonefs_mntdir"/seq/0)
[ "$sz" != "4096" ] && \
	exit_failed " --> Invalid file size $sz B, expected 4096 B"

echo "## file truncate to 0 (zone reset)"

truncate --no-create --size=0 "$zonefs_mntdir"/seq/0 || \
	exit_failed " --> FAILED"

sz=$(file_size "$zonefs_mntdir"/seq/0)
[ "$sz" != "0" ] && \
	exit_failed " --> Invalid file size $sz B, expected 0 B"

echo "## file truncate to after zone wp (e.g. 4096B)"

truncate --no-create --size=4096 "$zonefs_mntdir"/seq/0 && \
	exit_failed " --> SUCCESS (should FAIL)"

sz=$(file_size "$zonefs_mntdir"/seq/0)
[ "$sz" != "0" ] && \
	exit_failed " --> Invalid file size $sz B, expected 0 B"

echo "## file truncate to zone size (zone finish)"

maxsize=$(file_max_size "$zonefs_mntdir"/seq/0)
truncate --no-create --size=$maxsize "$zonefs_mntdir"/seq/0 || \
	exit_failed " --> FAILED"

sz=$(file_size "$zonefs_mntdir"/seq/0)
[ "$sz" != "$maxsize" ] && \
	exit_failed " --> Invalid file size $sz B, expected $maxsize B"

zonefs_umount

exit 0
