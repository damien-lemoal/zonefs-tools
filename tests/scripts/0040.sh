#!/bin/bash
#
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Copyright (C) 2019 Western Digital Corporation or its affiliates.
#

. scripts/test_lib

if [ $# == 0 ]; then
	echo "Number of files (default)"
        exit 0
fi

echo "Check for number of files: $nr_cnv_files cnv, $nr_seq_files seq"

zonefs_mkfs "$1"
zonefs_mount "$1"

if [ "$nr_cnv_files" != 0 ]; then
	nr_files=$(ls_nr_files "$zonefs_mntdir/cnv/")
	if [ "$nr_files" != "$nr_cnv_files" ]; then
		echo " --> Invalid number of conventional zones file:"
		echo " --> Expected $nr_cnv_files, got $nr_files"
		exit 1
	fi

	nr_files=$(file_size "$zonefs_mntdir/cnv")
	if [ "$nr_files" != "$nr_cnv_files" ]; then
		echo " --> Invalid cnv directory size:"
		echo " --> Expected $nr_cnv_files, got $nr_files"
		exit 1
	fi
fi

nr_files=$(ls_nr_files "$zonefs_mntdir/seq/")
if [ "$nr_files" != "$nr_seq_files" ]; then
	echo " --> Invalid number of sequential zones file:"
	echo " --> Expected $nr_seq_files, got $nr_files"
	exit 1
fi

nr_files=$(file_size "$zonefs_mntdir/seq/")
if [ "$nr_files" != "$nr_seq_files" ]; then
	echo " --> Invalid seq directory size:"
	echo " --> Expected $nr_seq_files, got $nr_files"
	exit 1
fi

zonefs_umount

exit 0
