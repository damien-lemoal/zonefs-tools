#!/bin/bash
#
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Copyright (C) 2022 Western Digital Corporation or its affiliates.
#

. scripts/test_lib

if [ $# == 0 ]; then
	echo "Conventional file seq write (aggr_cnv, large IOs)"
        exit 0
fi

require_cnv_files
require_program dd

zonefs_mkfs "-o aggr_cnv $1"
zonefs_mount "$1"

fsz=$(file_size "$zonefs_mntdir"/cnv/0)
bs=$(( 16 * 1024 * 1024 ))
if [ $bs -gt $fsz ]; then
	bs="$fsz"
fi
count=$(( fsz / bs ))
if [ $(( count * bs )) -ne $fsz ]; then
	count=$(( count + 1 ))
fi

echo "Check conventional file seq write (aggr_cnv, large IOs, buffered)"
echo "bs: $bs, count: $count, fsz: $fsz"

dd if=/dev/zero of="$zonefs_mntdir"/cnv/0 \
    bs="$bs" count="$count" conv=notrunc || \
    exit_failed " --> FAILED"

sync || exit_failed " --> FAILED"

echo "Check conventional file seq write (aggr_cnv, large_IOs, direct)"
echo "bs: $bs, count: $count, fsz: $fsz"

dd if=/dev/zero of="$zonefs_mntdir"/cnv/0 \
    bs="$bs" count="$count" conv=notrunc oflag=direct || \
    exit_failed " --> FAILED"

zonefs_umount

exit 0
