# SPDX-License-Identifier: CC0-1.0
#
# Copyright (C) 2019 Western Digital Corporation or its affiliates.

AM_CFLAGS = -O2 -Wall -Wextra -Wno-unused-parameter

sbin_PROGRAMS = mkzonefs

CFILES = zonefs_dev.c \
	 mkzonefs.c
HFILES = zonefs.h

mkzonefs_SOURCES = ${CFILES} ${HFILES}
mkzonefs_LDADD =
mkzonefs_LDFLAGS = -luuid -lblkid

install-exec-hook:
	(cd $(DESTDIR)${sbindir}; rm -f mkfs.zonefs)
	(cd $(DESTDIR)${sbindir}; $(LN_S) mkzonefs mkfs.zonefs)

uninstall-hook:
	(cd $(DESTDIR)${sbindir}; rm -f mkfs.zonefs)
