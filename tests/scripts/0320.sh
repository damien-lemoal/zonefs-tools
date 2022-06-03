#!/bin/bash
#
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Copyright (C) 2019 Western Digital Corporation or its affiliates.
#

. scripts/test_lib

if [ $# == 0 ]; then
	echo "Sequential file random read (buffered)"
        exit 0
fi

require_program fio

zonefs_mkfs "$1"
zonefs_mount "$1"

echo "Fill sequential file"

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

zonefs_umount

echo "Check sequential file random read (sync)"

zonefs_mount "$1"

# Sync buffered random read
fio --name=seq_rndrd --filename="$zonefs_mntdir"/seq/0 \
    --rw=randread --ioengine=psync --max-jobs=8 \
    --bs=131072 --verify=md5 --do_verify=1 \
    --continue_on_error=none || \
	exit_failed "fio sync rand read FAILED"

zonefs_umount

zonefs_mount "$1"

echo "Check sequential file random read (async)"

# Async buffered random read
fio --name=seq_rndrd --filename="$zonefs_mntdir"/seq/0 \
    --rw=randread --ioengine=libaio --iodepth=8 --max-jobs=8 \
    --bs=131072 --verify=md5 --do_verify=1 \
    --continue_on_error=none || \
	exit_failed "fio async rand read FAILED"

zonefs_umount


exit 0
