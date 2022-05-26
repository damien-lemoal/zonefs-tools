#!/bin/bash
#
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Copyright (C) 2021 Western Digital Corporation or its affiliates.
#

. scripts/test_lib

if [ $# == 0 ]; then
	echo "Swap file on sequential file"
        exit 0
fi

echo "Check swap file on sequential file"

zonefs_mkfs "$1"
zonefs_mount "$1"

# Fill the file
tools/zio --write --fflag=direct \
	--size=131072 --async=8 "$zonefs_mntdir"/seq/0 || \
	exit_failed " --> FAILED"
chmod 600 "$zonefs_mntdir"/seq/0 || \
	exit_failed " --> FAILED"

# mkswap should fail (cannot write swap file header)
mkswap "$zonefs_mntdir"/seq/0 && \
	exit_failed " --> SUCCESS (should FAIL)"

# Create a swap file and copy it to a sequential file to check
# the kernel side zonefs swap activate check.
sudo fallocate -l "$seq_file_0_max_size" /tmp/swapfile
chmod 600 /tmp/swapfile || \
	exit_failed " --> FAILED"
mkswap /tmp/swapfile || \
	exit_failed " --> FAILED"
dd if=/tmp/swapfile of="$zonefs_mntdir"/seq/0 \
	bs=131072 oflag=direct ||
	exit_failed " --> FAILED"

swapon "$zonefs_mntdir"/seq/0 && \
	exit_failed " --> SUCCESS (should FAIL)"

zonefs_umount

rm -f /tmp/swapfile

exit 0
