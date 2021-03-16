#!/bin/bash
#
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Copyright (C) 2021 Western Digital Corporation or its affiliates.
#

. scripts/test_lib

if [ $# == 0 ]; then
	echo "Swap file on conventional file"
        exit 0
fi

if [ "$nr_cnv_files" == 0 ]; then
	exit_skip
fi

echo "Check swap file on conventional file"

zonefs_mkfs "$1"
zonefs_mount "$1"

chmod 600 "$zonefs_mntdir"/cnv/0 || \
	exit_failed " --> FAILED"
mkswap "$zonefs_mntdir"/cnv/0 || \
	exit_failed " --> FAILED"

swapon "$zonefs_mntdir"/cnv/0 || \
	exit_failed " --> FAILED"

swapoff "$zonefs_mntdir"/cnv/0 || \
	exit_failed " --> FAILED"

zonefs_umount

exit 0
