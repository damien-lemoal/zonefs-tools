#!/bin/bash
#
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Copyright (C) 2022 Western Digital Corporation or its affiliates.
#

# Zone size in MB
zone_size=64
zone_capacity=$zone_size

# Device total capacity (MB)
capacity=2048

# Sector size
sect_size=512

# Number of conventional zones
nr_conv=3

function usage() {
	echo "Usage: $0 [options]"
	echo "Options:"
	echo "  -h | --help              : Display help"
	echo "  -c | --cap               : Test with zone capacity < zone size (default: off)"
	echo "  -n | --nr_conv <nr conv> : Specify the number of conventional zones to use."
	echo "  -t <test num>            : Test to execute. Can be specified multiple times."
	echo "  -r <num>                 : Repeat the selected test cases <num> times"
	echo "                             (default: num=1)"
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
		"-c" | "--cap")
			zone_capacity=$(( zone_size - 1 ))
                        shift
                        ;;
		"-n" | "--nr_conv")
			shift
			nr_conv="$1"
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

# trap ctrl-c interruptions
aborted=0
trap ctrl_c INT

function ctrl_c() {
	aborted=1
}

scriptdir="$(cd "$(dirname "$0")" && pwd)"

# Create the scsi_debug device
modprobe scsi_debug max_luns=1 sector_size="$sect_size" \
	delay=0 dev_size_mb="$capacity" zbc=managed \
	zone_size_mb="$zone_size" zone_cap_mb="$zone_capacity" \
	zone_nr_conv="$nr_conv"

sdev="$(lsscsi | grep scsi_debug | awk -F' ' '{print $NF}')"
sbdev="$(basename $sdev)"
zone_max_open=$(cat /sys/block/"$sbdev"/queue/max_open_zones)
zone_max_active=$(cat /sys/block/"$sbdev"/queue/max_active_zones)
nr_zones=$(blkzone report "$sdev" | wc -l)
nr_conv=$(blkzone report "$sdev" | grep -c CONVENTIONAL)

echo ""
echo "Run tests against $sdev..."
echo "    Zone size: $zone_size MB, zone capacity: $zone_capacity MB"
echo "    $nr_zones zones, $nr_conv conventional zones"
echo "    $zone_max_open max open zones"
echo "    $zone_max_active max active zones"
echo ""

declare -i rc=0
if ! ./zonefs-tests.sh ${testopts} "$sdev"; then
	rc=1
fi

sleep 1
rmmod scsi_debug

echo ""
if [ "$rc" != 0 ]; then
	echo "Failures detected"
	exit 1
fi

echo "All tests passed"
exit 0
