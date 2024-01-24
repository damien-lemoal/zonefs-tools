#!/bin/bash
#
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Copyright (C) 2019 Western Digital Corporation or its affiliates.
#

. scripts/test_lib

if [ $# == 0 ]; then
	echo "mkzonefs (force format)"
	exit 0
fi

require_program mkfs.f2fs
require_cnv_files

# Format with f2fs. Cap filesystem size up to 16TB per f2fs design.
sectors=$((nr_zones * zone_sectors))
sectors_16TB=$((16 * 1024 * 1024 * 1024 * 1024 / 512))
((sectors > sectors_16TB)) && sectors=$((sectors_16TB))
f2fs_sectors=$((sectors / ($(get_logical_block_size "$1") / 512)))
mkfs.f2fs -f -m "$1" $((f2fs_sectors)) || exit_failed " --> f2fs format FAILED"

# This should fail
echo "Check mkzonefs with used super block and not forced"
mkzonefs "$1" && exit_failed " --> FAILED"

# And pass if -f is specified
echo "Check mkzonefs with used super block and forced"
mkzonefs -f "$1" || exit_failed " --> FAILED"

exit 0
