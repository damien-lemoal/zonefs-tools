# SPDX-License-Identifier: GPL-2.0-or-later
#
# Copyright (c) 2021 Western Digital Corporation or its affiliates.
Name:		zonefs-tools
Version:	1.5.0
Release:	1%{?dist}
Summary:	User utilities for the zonefs file system

License:	GPLv2+
URL:		https://github.com/westerndigitalcorporation/%{name}
Source0:	https://github.com/westerndigitalcorporation/%{name}/archive/refs/tags/v%{version}.tar.gz

BuildRoot:	%{_topdir}/BUILDROOT/
BuildRequires:	libblkid-devel,libuuid-devel,autoconf,autoconf-archive,automake,libtool

%description
zonefs-tools provides the mkzonefs (mkfs.zonefs) user utility to
format zoned block devices for use with the zonefs file system.

%prep
%autosetup

%build
sh autogen.sh
%configure
%make_build

%install
rm -rf $RPM_BUILD_ROOT
mkdir -p $RPM_BUILD_ROOT
make install PREFIX=%{_prefix} DESTDIR=$RPM_BUILD_ROOT
chmod -x $RPM_BUILD_ROOT%{_mandir}/man8/*.8

find $RPM_BUILD_ROOT -name '*.la' -delete

%ldconfig_scriptlets

%files
%{_sbindir}/*
%{_mandir}/man8/*

%license COPYING.GPL
%doc README.md CONTRIBUTING

%changelog
* Sat May 22 2021 Damien Le Moal <damien.lemoal@wdc.com> 1.5.0-1
- Version 1.5.0 initial package
