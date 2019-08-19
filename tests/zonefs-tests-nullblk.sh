#!/bin/bash
#
# SPDX-License-Identifier: GPL-2.0
#
# Copyright (C) 2019 Western Digital Corporation or its affiliates.
#

scriptdir="$(cd "$(dirname "$0")" && pwd)"

for d in /sys/kernel/config/nullb/*; do [ -d "$d" ] && rmdir "$d"; done
modprobe -r null_blk
modprobe null_blk nr_devices=0 || return $?
for d in /sys/kernel/config/nullb/*; do
	[ -d "$d" ] && rmdir "$d"
done
modprobe -r null_blk
[ -e /sys/module/null_blk ] && exit $?

modprobe null_blk nr_devices=0

# Create null_blk regular disk
cd /sys/kernel/config/nullb
mkdir nullb0 && cd nullb0

echo 4096 > blocksize
echo 1 > power

# Create null_blk zoned disk
cd /sys/kernel/config/nullb
mkdir nullb1 && cd nullb1

echo 4096 > blocksize
echo 0 > completion_nsec
echo 0 > irqmode
echo 2 > queue_mode
echo 4096 > size
echo 1024 > hw_queue_depth
echo 1 > zoned
echo 64 > zone_size
echo 16 > zone_nr_conv
echo 1 > memory_backed

echo 1 > power

echo mq-deadline > /sys/block/nullb1/queue/scheduler

# Run tests
cd "$scriptdir"
./zonefs-tests.sh /dev/nullb1

# Remove null_blk
for d in /sys/kernel/config/nullb/nullb*; do
	echo 0 > "$d"/power
       	rmdir "$d"
done

modprobe -r null_blk

