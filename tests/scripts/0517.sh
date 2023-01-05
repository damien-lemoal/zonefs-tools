#!/bin/bash
#
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Copyright (C) 2022 Western Digital Corporation or its affiliates.
#

. scripts/test_lib

if [ $# == 0 ]; then
	echo "Sysfs conv files active after write"
        exit 0
fi

require_cnv_files
require_sysfs

zonefs_mkfs "$1"
zonefs_mount "$1"

i=0
maxact=$(get_max_active_zones "$1")
if [ ${maxact} -eq 0 ]; then
	maxact=4
fi
maxact=$(min ${maxact} ${nr_cnv_files})

# Write 4K in maxact conv files
for((i=0; i<${maxact}; i++)); do
	echo "Writing conv file ${i}"

	dd if=/dev/zero of="${zonefs_mntdir}/cnv/${i}" bs=4096 \
		count=1 oflag=direct conv=nocreat,notrunc || \
		exit_failed "Write cnv file ${i} failed"

	nract=$(sysfs_nr_active_seq_files "$1")
	[[ ${nract} -eq 0 ]] || \
		exit_failed "nr_active_seq_files is ${nract} (should be 0)"

	nrwro=$(sysfs_nr_wro_seq_files "$1")
	[[ ${nrwro} -eq 0 ]] || \
		exit_failed "nr_wro_seq_files is ${nrwro} after close (should be 0)"
done

zonefs_umount

exit 0
