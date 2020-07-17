#!/bin/bash
#
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Copyright (C) 2019 Western Digital Corporation or its affiliates.
#

# Zone size in MB
zone_size=64
zone_capacity=$zone_size

function usage() {
	echo "Usage: $0 [options]"
	echo "Options:"
	echo "\t-h | --help:	Display help"
	echo "\t-c | --cap:	Test with zone capacity < zone size (default: off)"
}

# Check credentials
if [ $(id -u) -ne 0 ]; then
        echo "Root credentials are needed to run tests."
        exit 1
fi

# Check options
if [ $# != 0 ]; then
	for arg in "$@"; do
		if [ "$arg" == "-c" ] || [ "$arg" == "--cap" ]; then
			zone_capacity=$(( zone_size - 1 ))
		elif [ "$arg" == "-h" ] || [ "$arg" == "--help" ]; then
			usage "$0"
			exit 0
		else
			echo "Invalid option $arg"
			exit 1
		fi
	done
fi

# trap ctrl-c interruptions
aborted=0
trap ctrl_c INT

function ctrl_c() {
	aborted=1
}

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

	if [ $zone_capacity != $zone_size ] && [ ! -w "$dev"/zone_capacity ]; then
		echo "Zone capacity is not supported by nullblk"
		exit 1
	fi

	echo 4096 > "$dev"/blocksize
	echo 0 > "$dev"/completion_nsec
	echo 0 > "$dev"/irqmode
	echo 2 > "$dev"/queue_mode

	echo 4096 > "$dev"/size
	echo 1024 > "$dev"/hw_queue_depth
	echo 1 > "$dev"/memory_backed

	echo 1 > "$dev"/zoned
	echo "$zone_size" > "$dev"/zone_size
	if [ $zone_capacity != $zone_size ]; then
		echo "$zone_capacity" > "$dev"/zone_capacity
	fi
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

declare -i rc=0

# Do 3 runs for 3 different drives: 16 conventional zones,
# 1 conventional zone and no conventional zones.
for c in 16 1 0; do

	echo ""
	echo "Run tests against device with $c conventional zones..."
	echo "Zone size: $zone_size MB, zone capacity: $zone_capacity MB"
	echo ""
	nulld=$(create_zoned_nullb $c)

	logfile="nullb${nulld}-cnv${c}-zonefs-tests.log"
	if ! ./zonefs-tests.sh "-g" "$logfile" "/dev/nullb$nulld"; then
		rc=1
	fi

	destroy_zoned_nullb "$nulld"

	if [ "$aborted" == 1 ]; then
		break
	fi

done

rmmod null_blk >> /dev/null 2>&1

echo ""
if [ "$rc" != 0 ]; then
	echo "Failures detected"
	exit 1
fi

echo "All tests passed"
exit 0
