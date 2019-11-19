#!/bin/bash
#
# SPDX-License-Identifier: GPL-2.0
#
# Copyright (C) 2019 Western Digital Corporation or its affiliates.
#

. scripts/test_lib

if [ $# == 0 ]; then
	echo "mkzonefs (super block zone state)"
	exit 0
fi

if zone_is_conventional "$1" "0"; then
	# The super block is in a conventional zone: nothing to do
    	echo "conventional zone"
	exit 0
fi

zonefs_mkfs "$1"

zone_is_full "$1" "0" || exit_failed " --> Super block zone is not in full state"

exit 0
