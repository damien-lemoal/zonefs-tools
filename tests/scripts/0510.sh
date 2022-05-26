#!/bin/bash
#
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Copyright (C) 2022 Western Digital Corporation or its affiliates.
#

. scripts/test_lib

if [ $# == 0 ]; then
	echo "Sysfs attr after format"
        exit 0
fi

require_sysfs

zonefs_mkfs "$1"
zonefs_mount "$1"

echo "Check max write open seq files"

dev_val=$(get_max_open_zones "$1")
sysfs_val=$(sysfs_max_wro_seq_files "$1")
[[ ${sysfs_val} -eq ${dev_val} ]] || \
	exit_failed "max_wro_seq_files is ${sysfs_val} (should be ${dev_val})"

echo "Check max active seq files"

dev_val=$(get_max_active_zones "$1")
sysfs_val=$(sysfs_max_active_seq_files "$1")
[[ ${sysfs_val} -eq ${dev_val} ]] || \
	exit_failed "max_active_seq_files is ${sysfs_val} (should be ${dev_val})"

echo "Check write open seq files count"

sysfs_val=$(sysfs_nr_wro_seq_files "$1")
[[ ${sysfs_val} -eq 0 ]] || \
	exit_failed "nr_wro_seq_files is ${sysfs_val} (should be 0)"

echo "Check active seq files count"

sysfs_val=$(sysfs_nr_active_seq_files "$1")
[[ ${sysfs_val} -eq 0 ]] || \
	exit_failed "nr_active_seq_files is ${sysfs_val} (should be 0)"

zonefs_umount

exit 0
