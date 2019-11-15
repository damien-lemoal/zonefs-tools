#!/bin/bash
#
# SPDX-License-Identifier: GPL-2.0
#
# Copyright (C) 2019 Western Digital Corporation or its affiliates.
#

function usage() {
    echo "Usage: $(basename "$0") [Options] <Zoned device node file>"
    echo "Options:"
    echo "  -l || --list: List all tests"
    echo "  -t <test num>: Test to execute. Can be specified multiple times."
    echo "  -h || --help: This help message"
}

blkzone=$(type -p blkzone 2>/dev/null)

function get_nr_zones() {
	${blkzone} report "/dev/$1" | wc -l || return 0
}

function get_nr_cnv_zones() {
	${blkzone} report "/dev/$1" | grep -c "CONVENTIONAL" || return 0
}

function get_nr_seq_zones() {
	${blkzone} report "/dev/$1" | grep -c "SEQ_WRITE_" || return 0
}

function get_zone_sectors() {
	cat "/sys/class/block/$1/queue/chunk_sectors"
}

function get_zone_bytes() {
	echo $(( $(get_zone_sectors "$1") * 512 ))
}

function test_num() {
	basename "$1" | cut -d "." -f1
}

# Check credentials
if [ $(id -u) -ne 0 ]; then
	echo "Root credentials are needed to run tests."
	exit 1
fi

declare -a tests
declare list=false

while [ "${1#-}" != "$1" ]; do
	case "$1" in
	-h | --help)
		usage
		exit 0
		;;
	-t)
		t="scripts/$2.sh"
		if [ ! -e "$t" ]; then
			echo "Invalid test number $2"
			exit 1;
		fi
		tests+=("$t")
		shift
		shift
		;;
	-l | --list)
		list=true
		shift
		;;
	-*)
		echo "unknow option $1"
		exit 1
		;;
	esac
done

if [ ! $list ] && [ $# -lt 1 ]; then
    usage
    exit 1
fi

# Get list of tests
if [ "${#tests[@]}" = 0 ]; then
	for f in  scripts/*.sh; do
		tests+=("$f")
	done
fi

# Handle -l option (list tests)
if $list; then
	for t in "${tests[@]}"; do
		echo "  Test $(test_num "$t"): $( $t )"
	done
	exit 0
fi

logfile=zonefs-tests.log
passed=0
total=0
rc=0

dev="$1"
if [ -z "$dev" ]; then
	usage
	exit 1
fi

realdev=$(readlink -f "$dev")
bdev=$(basename "$realdev")
major=$((0x$(stat -L -c '%t' "$realdev")))
minor=$((0x$(stat -L -c '%T' "$realdev")))

# When the target is a partition device, get basename of its holder device to
# access sysfs path of the holder device
if [[ -r "/sys/dev/block/$major:$minor/partition" ]]; then
        realsysfs=$(readlink "/sys/dev/block/$major:$minor")
        bdev=$(basename "${realsysfs%/*}")
fi

dev="/dev/$bdev"

if [ "$(<"/sys/class/block/$bdev/queue/zoned")" == "none" ]; then
	echo "/dev/$dev is not a zoned block device"
        exit 1
fi

echo "zonefs-tests on $dev:"

nr_zones=$(get_nr_zones "$bdev")
nr_cnv_zones=$(get_nr_cnv_zones "$bdev")
nr_seq_zones=$(get_nr_seq_zones "$bdev")
zone_sectors=$(get_zone_sectors "$bdev")
zone_bytes=$(get_zone_bytes "$bdev")

zonefs_mntdir="mnt"

echo "  $nr_zones zones ($nr_cnv_zones conventional zones, $nr_seq_zones sequential zones)"
echo "  $zone_sectors 512B sectors per zone ($(( zone_bytes / 1048576 )) MiB)"

# Set IO scheduler
echo deadline >"/sys/block/$bdev/queue/scheduler"

run_test() {
	local ret=0

	modprobe zonefs || (echo "FAILED (modprobe)"; return 1)

	echo "## Test $1 ($( $1 ))"
	echo ""
	if "$1" "$2" >> ${logfile} 2>&1; then
		echo "PASS"
	else
		echo "FAILED"
		ret=1
	fi
	echo ""

	umount "$zonefs_mntdir" >> /dev/null 2>&1
	rmmod zonefs || if [ $ret == 0 ]; then echo "FAILED (rmmod)"; ret=1; fi

	return $ret
}

export nr_zones
export nr_cnv_zones
export nr_seq_zones
export zone_sectors
export zone_bytes
export zonefs_mntdir

echo "Running tests"
rm -f "${logfile}"
mkdir -p "$zonefs_mntdir"

for t in "${tests[@]}"; do
	echo -n "  Test $(test_num "$t"):  "
	printf "%-64s ... " "$( $t )"

	if run_test "$t" "$1" >> ${logfile} 2>&1; then
		status="PASS"
		((passed++))
	else
		status="FAIL"
		rc=1
	fi

	((total++))
	echo "$status"
done

echo ""
echo "$passed / $total tests passed"

umount "$zonefs_mntdir" >> /dev/null 2>&1
rm -rf "$zonefs_mntdir" >> /dev/null 2>&1

exit $rc

