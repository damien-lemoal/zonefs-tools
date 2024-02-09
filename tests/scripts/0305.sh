#!/bin/bash
#
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Copyright (C) 2019 Western Digital Corporation or its affiliates.
#

. scripts/test_lib

if [ $# == 0 ]; then
	echo "Sequential file unaligned write (async)"
        exit 0
fi

require_program fio

echo "Check sequential file unaligned write (async IO)"

zonefs_mkfs "$1"
zonefs_mount "$1"

tools/zio --write --fflag=direct --ofst=4096 \
	--size=135168 --async=8 "$zonefs_mntdir"/seq/0 && \
	exit_failed " --> SUCCESS (should FAIL)"

sz=$(file_size "$zonefs_mntdir"/seq/0)
[ "$sz" != "0" ] && \
	exit_failed " --> Invalid file size $sz B, expected 0 B"

# The file should still be writable
dd if=/dev/zero of="$zonefs_mntdir"/seq/0 oflag=direct \
	bs=4096 count=1 conv=notrunc || \
	exit_failed " --> FAILED (should SUCCEED)"

zonefs_umount

exit 0
