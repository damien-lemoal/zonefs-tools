#!/bin/bash
#
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Copyright (C) 2019 Western Digital Corporation or its affiliates.
#

. scripts/test_lib

if [ $# == 0 ]; then
	echo "Sequential file random read"
        exit 0
fi

echo "Check sequential file random"

zonefs_mkfs "$1"
zonefs_mount "$1"

# Fill file
fio --name=seqwrite --filename="$zonefs_mntdir"/seq/0 \
    --create_on_open=0 --allow_file_create=0 --file_append=1 --unlink=0 \
    --rw=write --ioengine=libaio --iodepth=8 \
    --bs=131072 --size="$zone_bytes" --verify=md5 --do_verify=1 \
    --continue_on_error=none --direct=1 || \
	exit_failed "fio write FAILED"

sz=$(file_size "$zonefs_mntdir"/seq/0)
[ "$sz" != "$zone_bytes" ] && \
	exit_failed " --> Invalid file size $sz B, expected $zone_bytes B"

# Read
fio --name=seq_rndrd --filename="$zonefs_mntdir"/seq/0 \
    --rw=randread --ioengine=libaio --iodepth=8 \
    --bs=131072 --verify=md5 --do_verify=1 \
    --continue_on_error=none || \
	exit_failed "fio async rand read FAILED"

zonefs_umount

exit 0
