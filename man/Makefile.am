# SPDX-License-Identifier: CC0-1.0
#
# Copyright (C) 2019 Western Digital Corporation or its affiliates.

dist_man_MANS = mkzonefs.8

install-data-hook:
	(cd $(DESTDIR)${mandir}/man8; rm -f mkfs.zonefs.8.gz)
	(cd $(DESTDIR)${mandir}/man8; $(LN_S) mkzonefs.8.gz mkfs.zonefs.8.gz)

uninstall-hook:
	(cd $(DESTDIR)${mandir}/man8; rm -f mkfs.zonefs.8.gz)
