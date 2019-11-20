#!/bin/bash
#
# SPDX-License-Identifier: GPL-2.0
#
# Copyright (C) 2019 Western Digital Corporation or its affiliates.
#

. scripts/test_lib

if [ $# == 0 ]; then
	echo "Sequential file unaligned write (async IO)"
        exit 0
fi

echo "Check sequential file unaligned write (async IO)"

zonefs_mkfs "$1"
zonefs_mount "$1"

fio --name=seq_wr --filename="$zonefs_mntdir"/seq/0 \
    --create_on_open=0 --allow_file_create=0 --unlink=0 \
    --rw=write --ioengine=libaio --iodepth=8 \
    --bs=131072 --verify=md5 --do_verify=1 \
    --continue_on_error=none --direct=1 --offset=4096 && \
	exit_failed " --> SUCCESS (should FAIL)"

sz=$(file_size "$zonefs_mntdir"/seq/0)
[ "$sz" != "0" ] && \
	exit_failed " --> Invalid file size $sz B, expected 0 B"

zonefs_umount

exit 0
