#!/bin/bash
#
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Copyright (C) 2019 Western Digital Corporation or its affiliates.
#
. scripts/test_lib

# trap ctrl-c interruptions
aborted=0
trap ctrl_c INT

function ctrl_c() {
	aborted=1
}

function test_num()
{
	basename "$1" | cut -d "." -f1
}

function usage()
{
	echo "Usage: $(basename "$0") [Options] <Zoned device node file>"
	echo "Options:"
	echo "  -l             : List all tests"
	echo "  -g <file name> : Use file name for the test log file."
	echo "                   default: <dev name>-zonefs-tests.log"
	echo "  -t <test num>  : Execute only the specified test case. Can be"
	echo "                   specified multiple times."
	echo "  -s             : Short test (do not execute tests that take a"
	echo "                   long time)"
	echo "  -h, --help     : This help message"
}

# Check configuration
[[ $(type -P "tools/zio") && $(type -P "tools/zopen") ]] ||
	{
		echo "Test tools not found."
		echo "Run \"./configure --with-tests\" and recompile."
		exit 1
	}

[[ $(type -P "fio") ]] ||
	{
		echo "fio not found."
		echo "Installing fio is required to run tests."
		exit 1
	}

[[ $(type -P "mkzonefs") ]] ||
	{
		echo "mkzonefs not found."
		echo "Installing zonefs-tools is required to run tests."
		exit 1
	}

# Parse command line
declare -a tests
declare list=false
logfile=""
export short=false

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
	-l)
		list=true
		shift
		;;
	-g)
		shift
		logfile="$1"
		shift
		;;
	-s)
		short=true
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

dev="$1"
if [ -z "$dev" ]; then
	usage
	exit 1
fi

if [ ! -b "$dev" ]; then
	echo "Invalid block device"
	exit 1
fi

# Check credentials
if [ $(id -u) -ne 0 ]; then
	echo "Root credentials are needed to run tests."
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

if ! blkzone_has_zone_capacity "$dev"; then
	echo "blkzone utility is not reporting zone capacity."
	echo "util-linux update needed."
        exit 1
fi

export zonefs_mntdir="$bdev-mnt"
mkdir -p "$zonefs_mntdir"

if [ "$logfile" == "" ]; then
	logfile="$bdev-zonefs-tests.log"
	rm -f "${logfile}"
fi

passed=0
total=0
rc=0

# Drive parameters
echo "Gathering information on $dev..."
export nr_zones=$(get_nr_zones "$dev")
export zone_sectors=$(get_zone_sectors "$dev")
export zone_bytes=$(( zone_sectors * 512 ))
export nr_cnv_zones=$(get_nr_cnv_zones "$dev")
export nr_seq_zones=$(get_nr_seq_zones "$dev")
export total_usable_sectors=$(get_total_zone_capacity_sectors "$dev")
export iosize=$((4096 * 64))

# Expected number of files
if [ "$nr_cnv_zones" == 0 ]; then
	nr_cnv_files=0
	nr_seq_files=$(( nr_seq_zones - 1 ))
	seq_file_0_zone_start_sector=$(( zone_sectors * 2 ))
elif [ "$nr_cnv_zones" == 1 ]; then
	nr_cnv_files=0
	nr_seq_files=$nr_seq_zones
	seq_file_0_zone_start_sector=$zone_sectors
else
	nr_cnv_files=$(( nr_cnv_zones - 1 ))
	nr_seq_files=$nr_seq_zones
	seq_file_0_zone_start_sector=$(( nr_cnv_zones * zone_sectors ))
fi
export nr_cnv_files
export nr_seq_files
export seq_file_0_zone_start_sector
export seq_file_0_max_size=$(get_zone_capacity_bytes "$dev" $seq_file_0_zone_start_sector)

# zonefs features
modprobe zonefs
if [ -d "/sys/fs/zonefs" ]; then
	zonefs_has_sysfs=1
else
	zonefs_has_sysfs=0
fi
export zonefs_has_sysfs
rmmod zonefs

# Set IO scheduler
echo mq-deadline > "/sys/block/$bdev/queue/scheduler"
if [ $? != 0 ]; then
	echo "Failed to set scheduler to mq-deadline"
	exit 1
fi

run_test() {
	local ret=0

	modprobe zonefs || (echo "FAILED (modprobe)"; return 1)

	echo "## Test $1 ($( $1 ))"
	echo ""

	"$1" "$2" >> ${logfile} 2>&1
	ret=$?
	if [ "$ret" == 0 ]; then
		echo "PASS"
	elif [ "$ret" == 2 ]; then
		echo "skip"
	else
		echo "FAILED"
	fi
	echo ""

	umount "$zonefs_mntdir" >> /dev/null 2>&1
	rmmod zonefs || if [ $ret == 0 ]; then echo "FAILED (rmmod)"; ret=1; fi

	return $ret
}

echo "zonefs-tests on $dev:"
echo "  $nr_zones zones ($nr_cnv_zones conventional zones, $nr_seq_zones sequential zones)"
echo "  $zone_sectors 512B sectors zone size ($(( zone_bytes / 1048576 )) MiB)"
echo "  $(get_max_open_zones $dev) max open zones"
echo "  $(get_max_active_zones $dev) max active zones"
echo "Running tests"

for t in "${tests[@]}"; do
	echo -n "  Test $(test_num "$t"):  "
	printf "%-52s ... " "$( $t )"

	run_test "$t" "$1" >> ${logfile} 2>&1
	ret=$?
	if [ "$ret" == 0 ]; then
		status="\e[92mPASS\e[0m"
		rc=0
	elif [ "$ret" == 2 ]; then
		status="skip"
		rc=0
	else
		status="\e[31mFAIL\e[0m"
		rc=1
	fi

	if [ "$rc" == 0 ]; then
		((passed++))
	fi
	((total++))
	echo -e "$status"

	if [ "$aborted" == 1 ]; then
		break
	fi

	na=0
done

echo ""
echo "$passed / $total tests passed"

umount "$zonefs_mntdir" >> /dev/null 2>&1
rm -rf "$zonefs_mntdir" >> /dev/null 2>&1
rm -f local-* >> /dev/null 2>&1

if [ "$passed" != "$total" ]; then
	exit 1
fi

exit 0

