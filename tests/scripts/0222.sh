#!/bin/bash
#
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Copyright (C) 2022 Western Digital Corporation or its affiliates.
#

. scripts/test_lib

if [ $# == 0 ]; then
	echo "Conventional file readahead"
        exit 0
fi

require_cnv_files
require_program dd

echo "Check conventional file readahead"

zonefs_mkfs "$1"
zonefs_mount "$1"

bs=$(block_size "$zonefs_mntdir"/cnv/0)

dd if=/dev/zero of="$zonefs_mntdir"/cnv/0 conv=notrunc \
    oflag=direct bs="$bs" count=1 || \
    exit_failed " --> FAILED"

dd if="$zonefs_mntdir"/cnv/0 of=/dev/null \
    bs="$bs" count=1 || \
    exit_failed " --> FAILED"

zonefs_umount

exit 0
