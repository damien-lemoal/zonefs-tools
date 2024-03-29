#!/bin/bash
#
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Copyright (C) 2019 Western Digital Corporation or its affiliates.
#

. scripts/test_lib

if [ $# == 0 ]; then
	echo "Conventional file truncate"
        exit 0
fi

require_cnv_files

echo "Check conventional file truncate"

zonefs_mkfs "$1"
zonefs_mount "$1"

truncate --no-create --size=0 "$zonefs_mntdir"/cnv/0 && \
    exit_failed " --> SUCCESS (should FAIL)"

zonefs_umount

exit 0
