#!/bin/bash
#
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Copyright (C) 2019 Western Digital Corporation or its affiliates.
#

. scripts/test_lib

if [ $# == 0 ]; then
	echo "mkzonefs (options)"
	exit 0
fi

# Test various good mkzonefs options
OPTS_OK=(""
	 "-h"
	 "--help"
	 "--help"
	 "-v"
	 "-f"
	 "-o aggr_cnv"
	 "-o uid=0"
	 "-o gid=0"
	 "-o perm=777"
	 "-o aggr_cnv,uid=0,gid=0,perm=777")

for ((i = 0; i < ${#OPTS_OK[@]}; i++)); do
	clear_sb "$1"

	cmd="mkzonefs ${OPTS_OK[$i]} $1"

	echo "Check mkzonefs command: $cmd"

	$cmd || exit_failed " --> FAILED"
done

# Test various bad mkzonefs options
OPTS_BAD=("-bad-option"
	  "-o"
	  "-o invalid_feature"
	  "-o invalid,,list")

for ((i = 0; i < ${#OPTS_BAD[@]}; i++)); do
	cmd="mkzonefs ${OPTS_BAD[$i]} $1"

	echo "Check mkzonefs command: $cmd"

	$cmd && exit_failed " --> SUCCESS (should FAIL)"
done

exit 0
