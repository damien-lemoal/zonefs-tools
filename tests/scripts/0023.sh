#!/bin/bash
#
# SPDX-License-Identifier: GPL-2.0
#
# Copyright (C) 2019 Western Digital Corporation or its affiliates.
#

. scripts/test_lib

if [ $# == 0 ]; then
	echo "mount (options)"
        exit 0
fi

zonefs_mkfs "$1"

# Test good mount options
OPTS=("-o errors=repair"
      "-o errors=remount-ro"
      "-o errors=zone-ro"
      "-o errors=zone-offline")
for ((i = 0; i < ${#OPTS[@]}; i++)); do
	zonefs_mount "${OPTS[$i]} $1"
	zonefs_umount "$1"
done

# Test invalid mount options
OPTS=("-o errors=continue"
      "-o errors=panic"
      "-o foo=bar"
      "-o bad_option")
for ((i = 0; i < ${#OPTS[@]}; i++)); do
	zonefs_mount_err "${OPTS[$i]} $1"
done

exit 0
