#!/bin/bash
#
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Copyright (C) 2019 Western Digital Corporation or its affiliates.
#

. scripts/test_lib

if [ $# == 0 ]; then
	echo "Sequential file mmap read/write"
        exit 0
fi

require_program fio

echo "Check sequential file mmap write (should fail)"

zonefs_mkfs "$1"
zonefs_mount "$1"

# Fill the file for mmap
maxsize=$(file_max_size "$zonefs_mntdir"/seq/0)
truncate --no-create --size=$maxsize "$zonefs_mntdir"/seq/0 || \
        exit_failed " --> FAILED"

sz=$(file_size "$zonefs_mntdir"/seq/0)
[ "$sz" != "$maxsize" ] && \
        exit_failed " --> Invalid file size $sz B, expected $maxsize B"

# mmpa(MAP_WRITE) should fail
fio --name=cnv_mmapwr --filename="$zonefs_mntdir"/seq/0 \
    --create_on_open=0 --allow_file_create=0 --file_append=0 --unlink=0 \
    --rw=randwrite --ioengine=mmap --size="$sz" \
    --bs=4096 --continue_on_error=none && \
    exit_failed " --> FAILED"

# Reset the file
truncate --no-create --size=0 "$zonefs_mntdir"/seq/0 || \
        exit_failed " --> FAILED"

# Fill file
fio --name=seqwrite --filename="$zonefs_mntdir"/seq/0 \
    --create_on_open=0 --allow_file_create=0 --file_append=1 --unlink=0 \
    --rw=write --ioengine=libaio --iodepth=64 \
    --bs=4096 --size="$maxsize" --verify=md5 --do_verify=1 \
    --continue_on_error=none --direct=1 || \
	exit_failed "fio write FAILED"

sz=$(file_size "$zonefs_mntdir"/seq/0)
[ "$sz" != "$zone_bytes" ] && \
	exit_failed " --> Invalid file size $sz B, expected $zone_bytes B"

zonefs_umount

echo "Check sequential file mmap read"

zonefs_mount "$1"

fio --name=seq_rndrd --filename="$zonefs_mntdir"/seq/0 \
    --rw=randread --ioengine=mmap \
    --create_on_open=0 --allow_file_create=0 --unlink=0 \
    --bs=4096 --size="$maxsize" --verify=md5 --do_verify=1 \
    --continue_on_error=none || \
	exit_failed "fio mmap rand read FAILED"

zonefs_umount

exit 0
