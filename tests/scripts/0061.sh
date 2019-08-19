#!/bin/bash
#
# SPDX-License-Identifier: GPL-2.0
#
# Copyright (C) 2019 Western Digital Corporation or its affiliates.
#

. scripts/test_lib

if [ $# == 0 ]; then
	echo "Files size (aggr_cnv)"
        exit 0
fi

echo "Check for $(( zone_bytes * (nr_cnv_zones - 1) )) B file size"

zonefs_mkfs "-o aggr_cnv $1"
zonefs_mount "$1"
check_size true
zonefs_umount

exit 0
