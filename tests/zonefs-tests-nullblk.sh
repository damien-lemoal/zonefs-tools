#!/bin/bash
#
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Copyright (C) 2019 Western Digital Corporation or its affiliates.
#

# Zone size in MB
zone_size=32
zone_capacity=$zone_size

# Max open and active limits
declare -i zone_max_open=0
declare -i zone_max_active=0

# Device total capacity (MB)
capacity=2048

# Device block size
blocksize="512"

# Default number of conventional zones to test
nr_conv=10

function usage() {
	echo "Usage: $0 [options]"
	echo "Options:"
	echo "  -h | --help          : Display help"
	echo "  -n | --nr_conv <n>   : Specify the number of conventional zones to use."
	echo "  -s | --sectsz <sz B> : Test with device block size set to <sz> bytes (default: 512 B)"
	echo "  -t <test num>        : Test to execute. Can be specified multiple times."
	echo "                         If used, only the first nullb config is used"
	echo "  -r <num>             : Repeat the selected test cases <num> times"
	echo "                         (default: num=1)"
}

# Check credentials
if [ $(id -u) -ne 0 ]; then
        echo "Root credentials are needed to run tests."
        exit 1
fi

testopts=""

# Check options
while [[ $# -gt 0 ]]; do
        case "$1" in
		"-h" | "--help")
			usage "$0"
			exit 0
                        ;;
		"-n" | "--nr_conv")
			shift
			nr_conv=($1)
			shift
			;;
		"-s" | "--sectsz")
			shift
			blocksize=($1)
			shift
			;;
		"-t")
			shift
			testopts+=" -t $1"
			shift
			;;
		"-r")
			shift
			testopts+=" -r $1"
			shift
			;;
                *)
			echo "Invalid option $1"
			exit 1
                        ;;
        esac
done

if [ $blocksize != 512 ] && [ $blocksize != 4096 ]; then
	echo "Invalid sector size"
	exit 1
fi

# trap ctrl-c interruptions
aborted=0
trap ctrl_c INT

function ctrl_c() {
	aborted=1
}

scriptdir="$(cd "$(dirname "$0")" && pwd)"

modprobe null_blk nr_devices=0

nr_configs=6

function set_config()
{
        case "$1" in
		"0")
			zone_max_open=0
			zone_max_active=0
                        ;;
		"1")
			zone_max_open=$(( capacity / zone_size / 8 ))
			zone_max_active=0
                        ;;
		"2")
			zone_max_open=0
			zone_max_active=$(( capacity / zone_size / 8 + 1 ))
                        ;;
		"3")
			zone_max_open=$(( capacity / zone_size / 8 ))
			zone_max_active=$(( capacity / zone_size / 8 + 1 ))
                        ;;
		"4")
			capacity=$(( capacity + zone_size / 2 + 1 ))
			nr_conv=0
			zone_max_open=$(( capacity / zone_size / 8 ))
			zone_max_active=$(( capacity / zone_size / 8 + 1 ))
                        ;;
		"5")
			zone_capacity=$(( zone_size - 1 ))
			zone_max_open=$(( capacity / zone_size / 8 ))
			zone_max_active=$(( capacity / zone_size / 8 + 1 ))
                        ;;
                *)
			echo "Invalid configuration"
			exit 1
                        ;;
        esac
}

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

	echo "$blocksize" > "$dev"/blocksize
	echo 2 > "$dev"/queue_mode
	echo 2 > "$dev"/irqmode
	echo 2000 > "$dev"/completion_nsec

	echo $capacity > "$dev"/size
	echo 1024 > "$dev"/hw_queue_depth
	echo 1 > "$dev"/memory_backed

	echo 1 > "$dev"/zoned
	echo "$zone_size" > "$dev"/zone_size
	if [ $zone_capacity != $zone_size ]; then
		echo "$zone_capacity" > "$dev"/zone_capacity
	fi
	echo "$nr_conv" > "$dev"/zone_nr_conv

	if [ -f "$dev"/zone_max_open ]; then
		echo "$zone_max_open" > "$dev"/zone_max_open
	fi

	if [ -f "$dev"/zone_max_active ]; then
		echo "$zone_max_active" > "$dev"/zone_max_active
	fi

	echo 1 > "$dev"/power

	echo "nullb$n"
}

function destroy_zoned_nullb()
{
        local ndev="$1"

	if [ -e "/sys/kernel/config/nullb/$ndev" ]; then
		echo "0" > /sys/kernel/config/nullb/$ndev/power
	fi
	rmdir /sys/kernel/config/nullb/$ndev > /dev/null 2>&1
}

declare -i rc=0
declare -i nrtests=0
declare -i passed=0
declare -i skipped=0
declare -i failed=0

# Run all open/active configurations
for (( m=0; m<$nr_configs; m++ )); do

	set_config "$m"

	ndev=$(create_zoned_nullb)
	if [ ! -b "/dev/${ndev}" ]; then
		echo "Create null block device failed"
		exit 1
	fi

	moz=$(cat /sys/block/"$ndev"/queue/max_open_zones)
	maz=$(cat /sys/block/"$ndev"/queue/max_active_zones)
	nrz=$(blkzone report "/dev/$ndev" | wc -l)
	nrc=$(blkzone report "/dev/$ndev" | grep -c CONVENTIONAL)

	echo ""
	echo "Config ${m}:"
	echo "    Zone size: $zone_size MB, zone capacity: $zone_capacity MB"
	echo "    $nrz zones, $nrc conventional zones"
	echo "    $moz max open zones ($zone_max_open)"
	echo "    $maz max active zones ($zone_max_active)"
	echo ""

	logdir="logs/${ndev}-conv${nr_conv}-moz${zone_max_open}-maz${zone_max_active}"

	if ! ./zonefs-tests.sh ${testopts} "-g" "$logdir" "/dev/$ndev"; then
		rc=1
	fi

	sleep 1
	destroy_zoned_nullb "$ndev"

	val=$(tail -1 "${logdir}/zonefs-tests.log" | cut -f1 -d' ')
	passed=$(( passed + val ))

	val=$(tail -1 "${logdir}/zonefs-tests.log" | cut -f3 -d' ')
	nrtests=$(( nrtests + val ))

	val=$(tail -1 "${logdir}/zonefs-tests.log" | cut -f2 -d'(' | cut -f1 -d' ')
	skipped=$(( skipped + val ))

	val=$(tail -1 "${logdir}/zonefs-tests.log" | cut -f8 -d' ')
	failed=$(( failed + val ))

	if [ "$aborted" == 1 ] || [ "$testopts" != "" ]; then
		break
	fi

done

rmmod null_blk > /dev/null 2>&1

echo ""
echo "Overall results:"
echo "${passed} / ${nrtests} tests passed (${skipped} skipped, ${failed} failures)"

if [ "$rc" != 0 ]; then
	echo "Failures detected"
	exit 1
fi

echo "All tests passed"
exit 0
