#!/bin/bash
#
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Copyright (C) 2019 Western Digital Corporation or its affiliates.
#

. scripts/test_lib

if [ $# == 0 ]; then
        echo "Number of blocks using stat (aggr_cnv)"
        exit 0
fi

echo "Check for number of blocks of the file system"

zonefs_mkfs "-o aggr_cnv $1"
zonefs_mount "$1"

nr_blocks=$(block_number "$zonefs_mntdir")
sz_blocks=$(block_size "$zonefs_mntdir")
nr_expected_blocks=$(( (nr_zones - 1 ) * zone_bytes / sz_blocks ))

if [ "$nr_blocks" != "$nr_expected_blocks" ]; then
        echo " --> Invalid number of total number of blocks:"
        echo " --> Expected $nr_expected_blocks, got $nr_blocks"
        exit 1
fi

zonefs_umount

exit 0

