#!/bin/bash
#
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Copyright (C) 2019 Western Digital Corporation or its affiliates.
#

. scripts/test_lib

if [ $# == 0 ]; then
	echo "Sequential file unaligned write (sync)"
        exit 0
fi

echo "Check sequential file unaligned write (sync IO)"

zonefs_mkfs "$1"
zonefs_mount "$1"

dd if=/dev/zero of="$zonefs_mntdir"/seq/0 bs=4096 count=1 seek=1 && \
	exit_failed " --> SUCCESS (should FAIL)"

sz=$(file_size "$zonefs_mntdir"/seq/0)
[ "$sz" != "0" ] && \
	exit_failed " --> Invalid file size $sz B, expected 0 B"

zonefs_umount

exit 0
