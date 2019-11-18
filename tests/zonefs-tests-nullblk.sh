#!/bin/bash
#
# SPDX-License-Identifier: GPL-2.0
#
# Copyright (C) 2019 Western Digital Corporation or its affiliates.
#

scriptdir="$(cd "$(dirname "$0")" && pwd)"

modprobe null_blk nr_devices=0

# Create a zoned null_blk disk
function create_zoned_nullb()
{
	local n=0

	while [ 1 ]; do
		if [ ! -b "/dev/nullb$n" ]; then
			break
		fi
		n=$(( n + 1 ))
	done

	dev="/sys/kernel/config/nullb/nullb$n"
	mkdir "$dev"

	echo 4096 > "$dev"/blocksize
	echo 0 > "$dev"/completion_nsec
	echo 0 > "$dev"/irqmode
	echo 2 > "$dev"/queue_mode

	echo 4096 > "$dev"/size
	echo 1024 > "$dev"/hw_queue_depth
	echo 1 > "$dev"/memory_backed

	echo 1 > "$dev"/zoned
	echo 64 > "$dev"/zone_size
	echo $1 > "$dev"/zone_nr_conv

	echo 1 > "$dev"/power

	echo "$n"
}

function destroy_zoned_nullb()
{
        local n=$1

	echo 0 > /sys/kernel/config/nullb/nullb$n/power
	rmdir /sys/kernel/config/nullb/nullb$n
}

for c in 16 1 0; do

	echo ""
	echo "Run tests against device with $c conventional zones..."
	echo ""
	nulld=$(create_zoned_nullb $c)
	./zonefs-tests.sh "/dev/nullb$nulld"
	destroy_zoned_nullb "$nulld"

done

rmmod null_blk >> /dev/null 2>&1

