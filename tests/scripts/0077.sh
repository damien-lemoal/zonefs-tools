#!/bin/bash
#
# SPDX-License-Identifier: GPL-2.0
#
# Copyright (C) 2019 Western Digital Corporation or its affiliates.
#

. scripts/test_lib

if [ $# == 0 ]; then
	echo "Conventional file random write (aggr_cnv, direct)"
        exit 0
fi

if [ "$nr_cnv_zones" == "0" ]; then
	exit 0
fi

echo "Check conventional file random write, aggr_cnv, direct"

zonefs_mkfs "-o aggr_cnv $1"
zonefs_mount "$1"

fio --name=cnv_rndwr --filename="$zonefs_mntdir"/cnv/0 \
    --rw=randwrite --ioengine=libaio --iodepth=8 \
    --bs=131072 --verify=md5 --do_verify=1 --overwrite=1 \
    --continue_on_error=none --direct=1 || \
    exit_failed " --> FAILED"

exit 0
