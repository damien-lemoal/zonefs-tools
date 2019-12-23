#!/bin/bash
#
# SPDX-License-Identifier: GPL-2.0
#
# Copyright (C) 2019 Western Digital Corporation or its affiliates.
#

. scripts/test_lib

if [ $# == 0 ]; then
	echo "Conventional file mmap read/write (aggr_cnv)"
        exit 0
fi

if [ "$nr_cnv_files" == 0 ]; then
	exit_skip
fi

echo "Check conventional file mmap write (aggr_cnv)"

zonefs_mkfs "-o aggr_cnv $1"
zonefs_mount "$1"

maxsize=$(file_max_size "$zonefs_mntdir"/cnv/0)
fio --name=cnv_mmapwr --filename="$zonefs_mntdir"/cnv/0 \
    --rw=randwrite --ioengine=mmap --size="$maxsize" \
    --create_on_open=0 --allow_file_create=0 --file_append=0 --unlink=0 \
    --bs=4096 --verify=md5 --do_verify=1 --overwrite=1 \
    --continue_on_error=none || \
    exit_failed " --> FAILED"

zonefs_umount

echo "Check conventional file mmap read (aggr_cnv)"

zonefs_mount "$1"

fio --name=cnv_mmaprd --filename="$zonefs_mntdir"/cnv/0 \
    --rw=randread --ioengine=mmap -size="$maxsize" \
    --create_on_open=0 --allow_file_create=0 --file_append=0 --unlink=0 \
    --bs=4096 --verify=md5 --do_verify=1 --continue_on_error=none || \
    exit_failed " --> FAILED"

zonefs_umount

exit 0
