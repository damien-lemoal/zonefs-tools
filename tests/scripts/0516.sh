#!/bin/bash
#
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Copyright (C) 2022 Western Digital Corporation or its affiliates.
#

. scripts/test_lib

if [ $# == 0 ]; then
	echo "Sysfs conv files write-open"
        exit 0
fi

if [ "$nr_cnv_files" == 0 ]; then
	exit_skip
fi

require_sysfs

zonefs_mkfs "$1"
zonefs_mount "$1"

echo "Check write open"

# Check that opening a conv file does not change the write open count
tools/zopen --nrfiles="$nr_cnv_files" --fflag=read --pause "${zonefs_mntdir}/cnv" &
zopid=$!
sleep 1

nract=$(sysfs_nr_active_seq_files "$1")
[[ ${nract} -eq 0 ]] || \
	exit_failed "nr_active_seq_files is ${nract} after read open (should be 0)"

nrwro=$(sysfs_nr_wro_seq_files "$1")
[[ ${nrwro} -eq 0 ]] || \
	exit_failed "nr_wro_seq_files is ${nrwro} after read open (should be 0)"

kill ${zopid}
wait ${zopid}

nract=$(sysfs_nr_active_seq_files "$1")
[[ ${nract} -eq 0 ]] || \
	exit_failed "nr_active_seq_files is ${nract} after read close (should be 0)"

nrwro=$(sysfs_nr_wro_seq_files "$1")
[[ ${nrwro} -eq 0 ]] || \
	exit_failed "nr_wro_seq_files is ${nrwro} after read close (should be 0)"

# Same with write open
tools/zopen --nrfiles="$nr_cnv_files" --fflag=write --pause "${zonefs_mntdir}/cnv" &
zopid=$!
sleep 1

nract=$(sysfs_nr_active_seq_files "$1")
[[ ${nract} -eq 0 ]] || \
	exit_failed "nr_active_seq_files is ${nract} after write open (should be 0)"

nrwro=$(sysfs_nr_wro_seq_files "$1")
[[ ${nrwro} -eq 0 ]] || \
	exit_failed "nr_wro_seq_files is ${nrwro} after write open (should be 0)"

kill ${zopid}
wait ${zopid}

nract=$(sysfs_nr_active_seq_files "$1")
[[ ${nract} -eq 0 ]] || \
	exit_failed "nr_active_seq_files is ${nract} after write close (should be 0)"

nrwro=$(sysfs_nr_wro_seq_files "$1")
[[ ${nrwro} -eq 0 ]] || \
	exit_failed "nr_wro_seq_files is ${nrwro} after write close (should be 0)"

zonefs_umount

exit 0
