#!/bin/bash
#
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Copyright (C) 2019 Western Digital Corporation or its affiliates.
#

. scripts/test_lib

if [ $# == 0 ]; then
	echo "Number of files (aggr_cnv)"
        exit 0
fi

require_cnv_files

echo "Check for number of files: 1 cnv, $nr_seq_files seq"

zonefs_mkfs "-o aggr_cnv $1"
zonefs_mount "$1"

nr_files=$(ls "$zonefs_mntdir/cnv/" | wc -l)
if [ "$nr_files" != 1 ]; then
	echo " --> Invalid number of conventional zones file:"
	echo " --> Expected 1, got $nr_files"
	exit 1
fi

nr_files=$(file_size "$zonefs_mntdir/cnv/")
if [ "$nr_files" != 1 ]; then
	echo " --> Invalid cnv directory size:"
	echo " --> Expected 1, got $nr_files"
	exit 1
fi

nr_files=$(ls "$zonefs_mntdir/seq/" | wc -l)
if [ "$nr_files" != "$nr_seq_files" ]; then
	echo " --> Invalid number of sequential zones file:"
	echo " --> Expected $nr_seq_files, got $nr_files"
	exit 1
fi

nr_files=$(file_size "$zonefs_mntdir/seq/")
if [ "$nr_files" !=  "$nr_seq_files" ]; then
	echo " --> Invalid seq directory size:"
	echo " --> Expected $nr_seq_files, got $nr_files"
	exit 1
fi

zonefs_umount

exit 0
