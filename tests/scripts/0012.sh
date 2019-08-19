#!/bin/bash
#
# SPDX-License-Identifier: GPL-2.0
#
# Copyright (C) 2019 Western Digital Corporation or its affiliates.
#

if [ $# == 0 ]; then
	echo "mkzonefs (invalid device)"
	exit 0
fi

# Not a block device
mkzonefs /dev/console && exit_failed " --> SUCCESS (should FAIL)"

# Regular disk
modprobe null_blk
mkzonefs /dev/nullb0 && exit_failed " --> SUCCESS (should FAIL)"
rmmod null_blk

exit 0
