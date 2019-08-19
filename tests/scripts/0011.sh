#!/bin/bash
#
# SPDX-License-Identifier: GPL-2.0
#
# Copyright (C) 2019 Western Digital Corporation or its affiliates.
#

if [ $# == 0 ]; then
	echo "mkzonefs (-f)"
	exit 0
fi

# Format with f2fs
mkfs.f2fs -m "$1" || exit_failed " --> f2fs format FAILED"

# This should fail
echo "Check mkzonefs with used super block and not forced"
mkzonefs "$1" && exit_failed " --> FAILED"

# And pass if -f is specified
echo "Check mkzonefs with used super block and forced"
mkzonefs -f "$1" || exit_failed " --> FAILED"

exit 0
