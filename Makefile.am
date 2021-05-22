# SPDX-License-Identifier: CC0-1.0
#
# Copyright (C) 2019 Western Digital Corporation or its affiliates.

ACLOCAL_AMFLAGS = -I m4

SUBDIRS = src man tests/tools
EXTRA_DIST = autogen.sh README.md COPYING.GPL CONTRIBUTING

if BUILD_RPM

rpmdir = $(abs_top_builddir)/rpmbuild

EXTRA_DIST += zonefs-tools.spec
RPMARCH=`$(RPM) --eval %_target_cpu`

rpm: dist
	@echo "Building RPM package..."
	@mkdir -p $(rpmdir)
	@mv zonefs-tools-$(PACKAGE_VERSION).tar.gz v$(PACKAGE_VERSION).tar.gz
	$(RPMBUILD) -ta --clean -D "_topdir $(rpmdir)" v$(PACKAGE_VERSION).tar.gz
	@mv -f $(rpmdir)/RPMS/$(RPMARCH)/*.rpm $(abs_top_builddir)
	@mv -f $(rpmdir)/SRPMS/*.rpm $(abs_top_builddir)
	@rm -rf $(rpmdir)
	@rm -f v$(PACKAGE_VERSION).tar.gz
else

rpm:
	@echo "Building RPM packages requires rpmbuild and rpm utilities"
	exit 1

endif
