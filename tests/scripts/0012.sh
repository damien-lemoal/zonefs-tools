#!/bin/bash
#
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Copyright (C) 2019 Western Digital Corporation or its affiliates.
#

. scripts/test_lib

if [ $# == 0 ]; then
	echo "mkzonefs (invalid device)"
	exit 0
fi

# Not a block device
echo "# Trying /dev/console"

mkzonefs /dev/console && exit_failed " --> SUCCESS (should FAIL)"

# Regular block device
nulldev=$(create_nullb)
echo "# Trying regular block device /dev/nullb$nulldev"

mkzonefs "/dev/nullb$nulldev" && exit_failed " --> SUCCESS (should FAIL)"
destroy_nullb $nulldev

exit 0
