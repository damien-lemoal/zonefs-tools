#!/bin/bash
#
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Copyright (C) 2022 Western Digital Corporation or its affiliates.
#

. scripts/test_lib

if [ $# == 0 ]; then
	echo "Sequential file read beyond eof"
        exit 0
fi

echo "Check sequential file read beyond eof"

zonefs_mkfs "$1"
zonefs_mount "$1"

bs=$(block_size "$zonefs_mntdir"/seq/0)

dd if=/dev/zero of="$zonefs_mntdir"/seq/0 oflag=direct bs="$bs" count=1 || \
	exit_failed " --> FAILED"

sz=$(file_size "$zonefs_mntdir"/seq/0)
[ "$sz" != "$bs" ] && \
	exit_failed " --> Invalid file size $sz B, expected $bs B"

dd if="$zonefs_mntdir"/seq/0 of=/dev/null bs="$(( bs * 2 ))" count=1 || \
	exit_failed " --> FAILED"

echo "Check sequential file read beyond max size"

# Fill file
fio --name=seqwrite --filename="$zonefs_mntdir"/seq/0 \
    --create_on_open=0 --allow_file_create=0 --file_append=1 --unlink=0 \
    --rw=write --ioengine=libaio --iodepth=8 --max-jobs=8 \
    --bs=131072 --size="$seq_file_0_max_size" --verify=md5 --do_verify=1 \
    --continue_on_error=none --direct=1 || \
        exit_failed "fio write FAILED"

sz=$(file_size "$zonefs_mntdir"/seq/0)
[ "$sz" != "$seq_file_0_max_size" ] && \
        exit_failed " --> Invalid file size $sz B, expected $seq_file_0_max_size B"

ofst=$(( ($seq_file_0_max_size - 512) / 512 ))
dd if="$zonefs_mntdir"/seq/0 of=/dev/null \
    bs="$(( bs * 2 ))" count=1 seek="$ofst" || \
    exit_failed " --> FAILED"

zonefs_umount

exit 0
