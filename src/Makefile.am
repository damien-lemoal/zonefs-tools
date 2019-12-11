AM_CPPFLAGS = -O2 -Wall -Wextra -Wno-unused-parameter

sbin_PROGRAMS = mkzonefs

CFILES = zonefs_dev.c \
	 mkzonefs.c
HFILES = zonefs.h

mkzonefs_SOURCES = ${CFILES} ${HFILES}
mkzonefs_LDADD =
mkzonefs_LDFLAGS = -luuid -lblkid

install-exec-hook:
	$(LN_S) $(DESTDIR)$(sbindir)/mkzonefs $(DESTDIR)$(sbindir)/mkfs.zonefs

uninstall-hook:
	rm -f $(DESTDIR)$(sbindir)/mkfs.zonefs
