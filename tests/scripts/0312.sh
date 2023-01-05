#!/bin/bash
#
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Copyright (C) 2020 Western Digital Corporation or its affiliates.
#

. scripts/test_lib

generate_fio() {
	local nseq="$1"

	filesize=$(file_max_size "$zonefs_mntdir"/seq/0)
	if $short; then
		filesize=$((zone_sectors * 512 / 64))
	fi

	cat > 0312.fio << EOF
[global]
create_on_open=0
allow_file_create=0
file_append=1
unlink=0
rw=write
ioengine=psync
bs=${iosize}
filesize=${filesize}
continue_on_error=none
direct=1

[writefiles]
EOF

	for (( i=0; i<$nseq; i++ )); do
		truncate -s 0 "$zonefs_mntdir/seq/$i"
		echo "filename=$zonefs_mntdir/seq/$i" >> 0312.fio
	done
}

function cleanup {
	rm -f 0312.fio > /dev/null 2>&1
}
trap cleanup EXIT

if [ $# == 0 ]; then
	echo "Sequential file explicit-open zone resources"
        exit 0
fi

require_program fio

echo "Check explicit-open mounts"

max_open_zones=$(get_max_open_zones "$1")
if [ "$max_open_zones" == 0 ]; then
	exit_skip "No maximum open zone limit"
fi

zonefs_mkfs "$1"
zonefs_mount "-o explicit-open $1"

# fio write with less than $max_open_zones must succeed
echo "Check write in less than $max_open_zones max open files"
if [ "$max_open_zones" -gt "1" ]; then
	generate_fio "$(( max_open_zones - 1 ))"
	fio 0312.fio || exit_failed "fio write failed"
fi

# fio write with $max_open_zones must succeed
echo "Check write in exactly $max_open_zones max open files"
generate_fio "$max_open_zones"
fio 0312.fio || exit_failed "fio write failed"

# fio write with 2 * $max_open_zones must fail
echo "Check write in double $max_open_zones max open files"
nrfiles=$(min $(( max_open_zones * 2 )) $nr_seq_files)
generate_fio "$nrfiles"
fio 0312.fio && exit_failed "fio write succeeded (should fail)"

zonefs_umount

exit 0
