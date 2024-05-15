#!/bin/bash
#
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Copyright (C) 2020 Western Digital Corporation or its affiliates.
#

. scripts/test_lib

if [ $# == 0 ]; then
	echo "Sequential file large synchronous write"
        exit 0
fi

require_program fio

echo "Check sequential file sync write bigger than max-append size"

zonefs_mkfs "$1"
zonefs_mount "$1"

sz=$(file_max_size "$zonefs_mntdir"/seq/0)
truncate --no-create --size=0 "$zonefs_mntdir"/seq/0 || \
        exit_failed " --> FAILED"

pbs=$(block_size "$1")
mask=$(($pbs - 1))

bs=$(get_write_max_bytes "$1")
bs=$(($bs + $pbs))
if [ ${bs} -gt ${sz} ]; then
	bs=${sz}
fi
bs=$((($bs + $mask) & ~$mask))

echo "Using ${bs} IO size"

fio --name=seqwrite --filename="$zonefs_mntdir"/seq/0 \
    --create_on_open=0 --allow_file_create=0 --file_append=1 --unlink=0 \
    --rw=write --ioengine=psync \
    --bs="$bs" --size="$sz" --verify=md5 --do_verify=1 \
    --continue_on_error=none --direct=1 || \
	exit_failed "fio write FAILED"

zonefs_umount

exit 0

