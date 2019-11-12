#!/bin/bash
#
# SPDX-License-Identifier: GPL-2.0
#
# Copyright (C) 2019 Western Digital Corporation or its affiliates.
#

. scripts/test_lib

if [ $# == 0 ]; then
	echo "mount (check mount directory sub-directories)"
        exit 0
fi

zonefs_mkfs "$1"
zonefs_mount "$1"

if [ "$nr_cnv_zones" <= 1 ]; then
	if [ -d "$zonefs_mntdir/cnv/" ]; then
		echo "$zonefs_mntdir/cnv/ exits (should not exist)"
		exit 1
	fi
else
	if [ ! -d "$zonefs_mntdir/cnv/" ]; then
		echo "$zonefs_mntdir/cnv/ does not exit (should exist)"
		exit 1
	fi
fi

if [ ! -d "$zonefs_mntdir/seq/" ]; then
	echo "$zonefs_mntdir/seq/ does not exit (should exit)"
	exit 1
fi

zonefs_umount

exit 0
