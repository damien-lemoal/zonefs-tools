#!/bin/bash
#
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Copyright (C) 2022 Western Digital Corporation or its affiliates.
#

. scripts/test_lib

if [ $# == 0 ]; then
	echo "Sysfs seq files write-open (explicit-open)"
        exit 0
fi

require_sysfs

zonefs_mkfs "$1"
zonefs_mount "-o explicit-open $1"

i=0
devmaxopen=$(get_max_open_zones "$1")
devmaxactive=$(get_max_active_zones "$1")
maxopen=${devmaxopen}
if [ ${maxopen} -eq 0 ]; then
	maxopen=${devmaxactive}
	if [ ${maxopen} -eq 0 ]; then
		maxopen=4
	fi
fi

echo "Check read open"

# Check that any number of file can be read-open
for((i=1; i<=$(( maxopen + 1 )); i++)); do
	echo "Opening ${i} files for reading"

	tools/zopen --nrfiles="$i" --fflag=read --pause "${zonefs_mntdir}/seq" &
	zopid=$!
	sleep 1

	nract=$(sysfs_nr_active_seq_files "$1")
	nrwro=$(sysfs_nr_wro_seq_files "$1")

	kill ${zopid}
	wait ${zopid}

	[[ ${nract} -eq 0 ]] || \
		exit_failed "nr_active_seq_files is ${nract} (should be 0)"
	[[ ${nrwro} -eq 0 ]] || \
		exit_failed "nr_wro_seq_files is ${nrwro} (should be 0)"
done

echo "Check write open"

# Check that any number of file can be write-open
for((i=1; i<=${maxopen}; i++)); do
	echo "Opening ${i} files for writing"

	tools/zopen --nrfiles="$i" --fflag=write --pause "${zonefs_mntdir}/seq" &
	zopid=$!
	sleep 1

	nract=$(sysfs_nr_active_seq_files "$1")
	[[ ${nract} -eq ${i} ]] || \
		exit_failed "nr_active_seq_files is ${nract} (should be ${i})"

	nrwro=$(sysfs_nr_wro_seq_files "$1")
	[[ ${nrwro} -eq ${i} ]] || \
		exit_failed "nr_wro_seq_files is ${nrwro} (should be ${i})"

	# Close the files
	kill ${zopid}
	wait ${zopid}

	# Now all counters should be back to 0 since the files where not written
	nract=$(sysfs_nr_active_seq_files "$1")
	[[ ${nract} -eq 0 ]] || \
		exit_failed "nr_active_seq_files is ${nract} after close (should be 0)"

	nrwro=$(sysfs_nr_wro_seq_files "$1")
	[[ ${nrwro} -eq 0 ]] || \
		exit_failed "nr_wro_seq_files is ${nrwro} after close (should be 0)"
done

if [ ${devmaxopen} -ne 0 ]; then
	# Opening one more file than max-open should fail
	echo "Opening $(( maxopen + 1 )) files for writing (failure expected)"
	tools/zopen --nrfiles="$(( maxopen + 1 ))" \
		--fflag=write "${zonefs_mntdir}/seq" && \
		exit_failed "Write-opening $(( maxopen + 1 )) > ${maxopen} files succedded (should fail)"
fi

sleep 1

nract=$(sysfs_nr_active_seq_files "$1")
[[ ${nract} -eq 0 ]] || \
	exit_failed "nr_active_seq_files is ${nract} after close (should be 0)"

nrwro=$(sysfs_nr_wro_seq_files "$1")
[[ ${nrwro} -eq 0 ]] || \
	exit_failed "nr_wro_seq_files is ${nrwro} after close (should be 0)"

zonefs_umount

exit 0
