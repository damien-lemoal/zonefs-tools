#!/bin/bash
#
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Copyright (C) 2019 Western Digital Corporation or its affiliates.
#

. scripts/test_lib

if [ $# == 0 ]; then
	echo "Conventional file mmap read/write"
        exit 0
fi

require_cnv_files
require_program fio

echo "Check conventional file mmap write"

zonefs_mkfs "$1"
zonefs_mount "$1"

maxsize=$(file_max_size "$zonefs_mntdir"/cnv/0)
fio --name=cnv_mmapwr --filename="$zonefs_mntdir"/cnv/0 \
    --rw=randwrite --ioengine=mmap --size="$maxsize" \
    --create_on_open=0 --allow_file_create=0 --file_append=0 --unlink=0 \
    --bs="${iosize}" --verify=md5 --do_verify=1 --overwrite=1 \
    --continue_on_error=none || \
    exit_failed " --> FAILED"

zonefs_umount

echo "Check conventional file mmap read"

zonefs_mount "$1"

fio --name=cnv_mmaprd --filename="$zonefs_mntdir"/cnv/0 \
    --rw=randread --ioengine=mmap --size="$maxsize" \
    --create_on_open=0 --allow_file_create=0 --file_append=0 --unlink=0 \
    --bs="${iosize}" --verify=md5 --do_verify=1 --continue_on_error=none || \
    exit_failed " --> FAILED"

zonefs_umount

exit 0
