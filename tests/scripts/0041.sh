#!/bin/bash
#
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Copyright (C) 2019 Western Digital Corporation or its affiliates.
#

. scripts/test_lib

if [ $# == 0 ]; then
	echo "Files permissions (aggr_cnv)"
        exit 0
fi

require_cnv_files

echo "Check for files permission 640 (aggr_cnv)"

zonefs_mkfs "-o aggr_cnv $1"
zonefs_mount "$1"
check_perm "640"
zonefs_umount

exit 0
