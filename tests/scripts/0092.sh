#!/bin/bash
#
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Copyright (C) 2020 Western Digital Corporation or its affiliates.
#

. scripts/test_lib

generate_fio() {
	local nseq="$1"

	filename="$zonefs_mntdir/seq/0"
	for (( i = 1; i < $nseq; i++ )); do
		filename="$filename:$zonefs_mntdir"/seq/$i
	done

	cat > 0092.fio << EOF
[global]
create_on_open=0
allow_file_create=0
file_append=1
unlink=0
rw=write
ioengine=libaio
iodepth=64
bs=4k
filesize=$(file_max_size "$zonefs_mntdir"/seq/0)
continue_on_error=none
direct=1

[less-than-MOZ]
filename=$filename
EOF
}

if [ $# == 0 ]; then
	echo "explicit-open mounts"
        exit 0
fi

require_program fio

echo "Check explicit-open mounts"

max_open_zones=$(get_max_open_zones "$1")

if [ "$max_open_zones" == 0 ]; then
	exit_skip
fi

zonefs_mkfs "$1"
zonefs_mount "-o explicit-open $1"


# fio write with less than $max_open_zones must succeed
if [ "$max_open_zones" -gt 1 ]; then

	generate_fio $(($max_open_zones - 1))
	
	fio 0092.fio || exit_failed "fio write failed"
	rm 0092.fio
fi

# fio write with $max_open_zones must succeed
generate_fio $max_open_zones

fio 0092.fio || exit_failed "fio write failed"
rm 0092.fio

# fio write with 2 * $max_open_zones must fail
generate_fio $(($max_open_zones * 2))

fio 0092.fio && exit_failed "fio write succeeded (should fail)"
rm 0092.fio

zonefs_umount

exit 0
