#!/bin/bash
#
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Copyright (C) 2019 Western Digital Corporation or its affiliates.
#

. scripts/test_lib

if [ $# == 0 ]; then
	echo "Sequential file unlink"
        exit 0
fi

echo "Check sequential file unlink"

zonefs_mkfs "$1"
zonefs_mount "$1"

rm -f "$zonefs_mntdir"/seq/0 && \
	exit_failed " --> SUCCESS (should FAIL)"

zonefs_umount

exit 0
