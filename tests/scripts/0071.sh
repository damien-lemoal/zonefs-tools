#!/bin/bash
#
# SPDX-License-Identifier: GPL-2.0
#
# Copyright (C) 2019 Western Digital Corporation or its affiliates.
#

. scripts/test_lib

if [ $# == 0 ]; then
	echo "Conventional file truncate (aggr_cnv)"
        exit 0
fi

if [ "$nr_cnv_zones" == "0" ]; then
	exit 0
fi

echo "Check conventional file truncate, aggr_cnv"

zonefs_mkfs "-o aggr_cnv $1"
zonefs_mount "$1"

truncate --no-create --size=0 "$zonefs_mntdir"/cnv/0 && \
    exit_failed " --> SUCCESS (should FAIL)"

zonefs_umount

exit 0
