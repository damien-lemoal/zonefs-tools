#!/bin/bash
#
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Copyright (C) 2019 Western Digital Corporation or its affiliates.
#

# Run everything from the tests directory
cd $(dirname "$0")

. scripts/test_lib

# trap ctrl-c interruptions
aborted=0
trap ctrl_c INT

function test_num()
{
	basename "$1" .sh
}

function ctrl_c() {
	aborted=1
}

function usage()
{
	echo "Usage: $(basename "$0") [Options] <Zoned device node file>"
	echo "Options:"
	echo "  -l                  : List all tests"
	echo "  -g <directory>      : Use this directory to save log files."
	echo "                        default: logs/<dev name>"
	echo "  -t <case>[-<case2>] : Execute only the specified test <case>."
	echo "                        If a second case is specified after a hyphen,"
	echo "                        all test cases from <case> to <case2> will be"
	echo "                        executed. This option can be specified"
	echo "                        multiple times."
	echo "  -s                  : Short test (do not execute tests that take a"
	echo "                        long time)"
	echo "  -r <num>            : Repeat the selected test cases <num> times"
	echo "                        (default: num=1)"
	echo "  -h, --help          : This help message"
}

# Check configuration
[[ $(modinfo null_blk) ]] ||
	{
		echo "null_blk module is not available."
		exit 1
	}

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
logdir=""
export short=false
declare nrloops=1

# Get full test list
declare -a testlist
for f in  scripts/*.sh; do
	testlist+=("$(test_num $f)")
done

function get_test_range()
{
	local case="$1"
	local tstart=$(echo "${case}" | cut -f1 -d'-')
	local tend=$(echo "${case}" | cut -f2 -d'-')
	local add=0
	declare -a trange

	for t in "${testlist[@]}"; do

		if [ "$t" == "$tstart" ]; then
			add=1
		fi

		if [ "$add" == "1" ]; then
			trange+=("scripts/$t.sh")
		fi

		if [ "$t" == "$tend" ]; then
			add=0
		fi
	done

	if [ "${#trange[@]}" == "0" ]; then
		echo "Invalid test range $1"
		exit 1;
	fi

	tests+=( "${trange[@]}" )
}

while [ "${1#-}" != "$1" ]; do
	case "$1" in
	-h | --help)
		usage
		exit 0
		;;
	-t)
		get_test_range "$2"
		shift
		shift
		;;
	-l)
		list=true
		shift
		;;
	-g)
		shift
		logdir="$1"
		shift
		;;
	-s)
		short=true
		shift
		;;
	-r)
		nrloops="$2"
		shift
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
if [ "${#tests[@]}" == "0" ]; then
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

# Check number of loops
if [ ${nrloops} -eq 0 ]; then
	echo "Invalid number of repetitions"
	exit 1
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

export zonefs_mntdir="${PWD}/$bdev-mnt"
mkdir -p "$zonefs_mntdir"

if [ "$logdir" == "" ]; then
	logdir="logs/${bdev}"
fi

mkdir -p "$logdir" || \
	exit_failed "Create log directory ${logdir} failed"
rm -rf "${logdir}/*" > /dev/null 2>&1
export logdir

passed=0
skipped=0
failed=0

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
	seq_file_0_zone_start_sector=$zone_sectors
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
zonefs_module=$(modprobe -c | grep -c zonefs)
if [ $zonefs_module != 0 ]; then
	modprobe zonefs
else
	have_zonefs=$(cat /proc/filesystems | grep -c zonefs)
	if [ $have_zonefs -eq 0 ]; then
		exit_failed "The kernel does not support zonefs"
	fi
fi
export zonefs_module

if [ -d "/sys/fs/zonefs" ]; then
	zonefs_has_sysfs=1
else
	zonefs_has_sysfs=0
fi
export zonefs_has_sysfs
if [ $zonefs_module != 0 ]; then
	rmmod zonefs
fi

# Set IO scheduler
set_io_scheduler "${bdev}" "mq-deadline" || \
	exit_failed "Set ${bdev} scheduler to mq-deadline failed"

function kmsg_log()
{
	if [ -e /dev/kmsg ]; then
		echo "$1" > /dev/kmsg
	fi
}

function kmsg_log_start()
{
	kmsg_log "++++ zonefs-test case $1 start ++++"
}

function kmsg_log_end()
{
	kmsg_log "---- zonefs-test case $1 end ----"
}

function run_test()
{
	local tnum="$(test_num $1)"
	local ret=0

	kmsg_log_start ${tnum}

	if [ $zonefs_module != 0 ]; then
		modprobe zonefs || (echo "FAILED (modprobe)"; return 1)
	fi

	echo "## Test ${tnum}: $( $1 )"
	echo ""

	"$1" "$2"
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
	if [ $zonefs_module != 0 ]; then
		rmmod zonefs || if [ $ret == 0 ]; then echo "FAILED (rmmod)"; ret=1; fi
	fi

	kmsg_log_end ${tnum}

	return $ret
}

runlog="${logdir}/zonefs-tests.log"

# Start logging the run
{

echo "zonefs-tests on $dev:"
echo "  $nr_zones zones ($nr_cnv_zones conventional zones, $nr_seq_zones sequential zones)"
echo "  $zone_sectors 512B sectors zone size ($(( zone_bytes / 1048576 )) MiB)"
echo "  $(get_max_open_zones $dev) max open zones"
echo "  $(get_max_active_zones $dev) max active zones"

if [ ${nrloops} -eq 1 ]; then
	echo "Running tests"
else
	echo "Running tests ${nrloops} times"
fi

nrtests=0

for ((r=1; r<=${nrloops}; r++)); do

	if [ ${nrloops} -ne 1 ]; then
		echo ""
		echo "Run ${r}:"
	fi

	nrtests=$(( nrtests + ${#tests[@]}))

	for t in "${tests[@]}"; do
		tnum="$(test_num $t)"

		echo -n "  Test ${tnum}: "
		printf "%-60s ... " "$( $t )"

		run_test "$t" "$1" > "${logdir}/${tnum}.log" 2>&1
		ret=$?
		if [ "$ret" == 0 ]; then
			status="\e[92mPASS\e[0m"
			((passed++))
		elif [ "$ret" == 2 ]; then
			status="skip"
			((skipped++))
		else
			status="\e[31mFAIL\e[0m"
			((failed++))
		fi

		echo -e "$status"

		if [ -f "${logdir}/.zonefs_test_nullbn" ]; then
			destroy_nullb "$(cat ${logdir}/.zonefs_test_nullbn)"
		fi

		if [ "$aborted" == 1 ]; then
			break
		fi

		na=0
	done

	if [ "$aborted" == 1 ]; then
		break
	fi
done

echo ""
echo "${passed} / ${nrtests} tests passed (${skipped} skipped, ${failed} failures)"

# End logging the run
} | tee -i "${runlog}" 2>&1

failed=$(grep -Po "skipped, \K[0-9]*" "${runlog}")

umount "$zonefs_mntdir" >> /dev/null 2>&1
rm -rf "$zonefs_mntdir" >> /dev/null 2>&1
rm -f local-* >> /dev/null 2>&1

# cleanup env
unset short
unset zonefs_mntdir
unset logdir
unset nr_zones
unset zone_sectors
unset zone_bytes
unset nr_cnv_zones
unset nr_seq_zones
unset total_usable_sectors
unset iosize
unset nr_cnv_files
unset nr_seq_files
unset seq_file_0_zone_start_sector
unset seq_file_0_max_size
unset zonefs_has_sysfs

if [ ${failed} -ne 0 ]; then
	exit 1
fi

exit 0

