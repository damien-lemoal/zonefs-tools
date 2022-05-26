#!/bin/bash
#
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Copyright (C) 2019 Western Digital Corporation or its affiliates.
#

. scripts/test_lib

if [ $# == 0 ]; then
	echo "Files permissions (default)"
        exit 0
fi

echo "Check for files permission 640"

zonefs_mkfs "$1"
zonefs_mount "$1"
check_perm "640"
zonefs_umount

exit 0
