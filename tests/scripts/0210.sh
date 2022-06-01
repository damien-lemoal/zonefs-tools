#!/bin/bash
#
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Copyright (C) 2022 Western Digital Corporation or its affiliates.
#

. scripts/test_lib

if [ $# == 0 ]; then
	echo "Conventional file seq write"
        exit 0
fi

require_cnv_files
require_program fio

echo "Check conventional file seq write (sync)"

zonefs_mkfs "$1"
zonefs_mount "$1"

fio --name=cnv_seqwr --filename="$zonefs_mntdir"/cnv/0 \
    --rw=write --ioengine=psync \
    --bs=131072 --verify=md5 --do_verify=1 --overwrite=1 \
    --continue_on_error=none || \
    exit_failed " --> FAILED"

zonefs_umount

echo "Check conventional file seq write (async)"

zonefs_mkfs "$1"
zonefs_mount "$1"

fio --name=cnv_seqwr --filename="$zonefs_mntdir"/cnv/0 \
    --rw=write --ioengine=libaio --iodepth=64 \
    --bs=131072 --verify=md5 --do_verify=1 --overwrite=1 \
    --continue_on_error=none || \
    exit_failed " --> FAILED"

zonefs_umount

exit 0
