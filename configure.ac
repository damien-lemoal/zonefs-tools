# SPDX-License-Identifier: CC0-1.0
#
# Copyright (C) 2019 Western Digital Corporation or its affiliates.

AC_INIT([zonefs tools], [1.5.1], [damien.lemoal@wdc.com])

AC_PREFIX_DEFAULT(/usr)
AC_CONFIG_HEADER([src/config.h])
AC_CONFIG_MACRO_DIR([m4])
AC_CONFIG_AUX_DIR([build-aux])
AM_INIT_AUTOMAKE([-Wall foreign subdir-objects])
AM_SILENT_RULES([yes])

AC_USE_SYSTEM_EXTENSIONS
AC_SYS_LARGEFILE
AC_GNU_SOURCE

m4_ifdef([AM_PROG_AR], [AM_PROG_AR])
m4_pattern_allow([AM_PROG_AR])
LT_INIT

# Checks for programs.
AC_PROG_CC
AM_PROG_CC_C_O
AC_PROG_LIBTOOL
AC_PROG_LN_S

# Checks for header files.
AC_CHECK_HEADER(libgen.h, [],
		[AC_MSG_ERROR([Couldn't find libgen.h])])
AC_CHECK_HEADER(mntent.h, [],
		[AC_MSG_ERROR([Couldn't find mntent.h])])
AC_CHECK_HEADER(linux/fs.h, [],
		[AC_MSG_ERROR([Couldn't find linux/fs.h])])
AC_CHECK_HEADER(blkid/blkid.h, [],
		[AC_MSG_ERROR([Couldn't find blkid/blkid.h])])
AC_CHECK_HEADER(linux/aio_abi.h, [],
		[AC_MSG_ERROR([Couldn't find linux/aio_abi.h])])
AC_CHECK_HEADER(linux/blkzoned.h, [],
		[AC_MSG_ERROR([Couldn't find linux/blkzoned.h])])

# Checks for libraries.
AC_SEARCH_LIBS([blkid_do_fullprobe], [blkid], [],
	       [AC_MSG_ERROR([Couldn't find libblkid])])
AC_SEARCH_LIBS([uuid_generate], [uuid], [],
	       [AC_MSG_ERROR([Couldn't find libuuid])])

# Checks for rpm package builds
AC_PATH_PROG([RPMBUILD], [rpmbuild], [notfound])
AC_PATH_PROG([RPM], [rpm], [notfound])
AM_CONDITIONAL([BUILD_RPM],
		[test "x$RPMBUILD" != xnotfound && test "x$RPM" != xnotfound])

AC_CONFIG_FILES([
	Makefile
	man/Makefile
	src/Makefile
	tests/tools/Makefile
])

AC_OUTPUT

