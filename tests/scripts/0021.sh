#!/bin/bash
#
# SPDX-License-Identifier: GPL-2.0
#
# Copyright (C) 2019 Western Digital Corporation or its affiliates.
#

. scripts/test_lib

if [ $# == 0 ]; then
	echo "mount (invalid device)"
        exit 0
fi

# Invalid device
echo "Check mount with invalid device"
zonefs_mount_err /dev/console

# Regular device
echo "Check mount with non-zoned block device"
modprobe null_blk
zonefs_mount_err /dev/nullb0
rmmod null_blk

exit 0
