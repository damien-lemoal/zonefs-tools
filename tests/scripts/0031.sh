#!/bin/bash
#
# SPDX-License-Identifier: GPL-2.0
#
# Copyright (C) 2019 Western Digital Corporation or its affiliates.
#

. scripts/test_lib

if [ $# == 0 ]; then
	echo "Number of files (aggr_cnv)"
        exit 0
fi

echo "Check for number of files: 1 aggr_cnv, $nr_seq_zones seq"

zonefs_mkfs "-o aggr_cnv $1"
zonefs_mount "$1"

if [ "$nr_cnv_zones" != 0 ]; then
	nr_files=$(ls "$zonefs_mntdir/cnv/" | wc -l)
	if [ "$nr_files" != "1" ]; then
		echo " --> Invalid number of conventional zones file:"
		echo " --> Expected 1, got $nr_files"
		exit 1
	fi
fi

nr_files=$(ls "$zonefs_mntdir/seq/" | wc -l)
if [ "$nr_files" != "$nr_seq_zones" ]; then
	echo " --> Invalid number of sequential zones file:"
	echo " --> Expected $nr_seq_zones, got $nr_files"
	exit 1
fi

zonefs_umount

exit 0