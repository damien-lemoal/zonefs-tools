# SPDX-License-Identifier: CC0-1.0
#
# Copyright (C) 2019 Western Digital Corporation or its affiliates.

ACLOCAL_AMFLAGS = -I m4

SUBDIRS = src man tests/tools
EXTRA_DIST = autogen.sh

if BUILD_RPM

rpmdir = $(abs_top_builddir)/rpmbuild

EXTRA_DIST += zonefs-tools.spec
RPMARCH=`$(RPM) --eval %_target_cpu`

spec: zonefs-tools.spec.in
	@echo "Generating rpm spec file..."
	@echo "Version:        $(PACKAGE_VERSION)" > zonefs-tools.spec
	@cat zonefs-tools.spec.in | grep -v '# ' >> zonefs-tools.spec

rpm: spec dist
	@echo "Building RPM package..."
	@mkdir -p $(rpmdir)
	$(RPMBUILD) -ta --clean -D "_topdir $(rpmdir)" zonefs-tools-$(PACKAGE_VERSION).tar.gz
	@mv -f $(rpmdir)/RPMS/$(RPMARCH)/*.rpm $(abs_top_builddir)
	@mv -f $(rpmdir)/SRPMS/*.rpm $(abs_top_builddir)
	@rm -rf $(rpmdir)
	@rm -f zonefs-tools-$(PACKAGE_VERSION).tar.gz
	@rm -f zonefs-tools.spec
else

rpm:
	@echo "Building RPM packages requires rpmbuild and rpm utilities"
	exit 1

endif
