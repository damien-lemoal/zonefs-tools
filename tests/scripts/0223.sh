#!/bin/bash
#
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Copyright (C) 2022 Western Digital Corporation or its affiliates.
#

. scripts/test_lib

if [ $# == 0 ]; then
	echo "Conventional file read beyond eof"
        exit 0
fi

require_cnv_files
require_program dd

echo "Check conventional file read beyond eof"

zonefs_mkfs "$1"
zonefs_mount "$1"

bs=$(block_size "$zonefs_mntdir"/seq/0)

sz=$(file_size "$zonefs_mntdir"/cnv/0)
ofst=$(( ($sz - 512) / 512 ))
dd if="$zonefs_mntdir"/cnv/0 of=/dev/null \
    bs="$(( bs * 2 ))" count=1 seek="$ofst" || \
    exit_failed " --> FAILED"

zonefs_umount

exit 0
