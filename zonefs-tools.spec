Name:		zonefs-tools
Version:	1.5.1
Release:	1%{?dist}
Summary:	Provides user utilities for the zonefs file system

License:	GPLv2+
URL:		https://github.com/westerndigitalcorporation/%{name}
Source0:	%{url}/archive/v%{version}/%{name}-%{version}.tar.gz

BuildRequires:	libblkid-devel
BuildRequires:	libuuid-devel
BuildRequires:	autoconf
BuildRequires:	autoconf-archive
BuildRequires:	automake
BuildRequires:	libtool
BuildRequires:	make
BuildRequires:	gcc

%description
This package provides the mkzonefs (and mkfs.zonefs) user utility
to format zoned block devices for use with the zonefs file system.

%prep
%autosetup

%build
sh autogen.sh
%configure
%make_build

%install
%make_install

%files
%{_sbindir}/*
%{_mandir}/man8/*

%license COPYING.GPL
%doc README.md CONTRIBUTING

%changelog
* Fri Jun 18 2021 Damien Le Moal <damien.lemoal@wdc.com> 1.5.1-1
- Version 1.5.1 initial package
