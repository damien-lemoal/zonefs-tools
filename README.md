Copyright (C) 2019, Western Digital Corporation or its affiliates.

# <p align="center">zonefs tools</p>

This project provides the *mkzonefs* command line utility which allows
formatting zoned block devices for use withe the *zonefs* file system.

## The *zonefs* File System

*zonefs* is a very simple file system exposing each zone of a zoned block device
as a file. *zonefs* does not have complex on-disk metadata. Its implementation
relies solely on a super block stored at LBA 0 of the device. On mount,
*zonefs* uses zone configuration information obtained directly from the device
to populate the mount point with files representing the device zones.

By default, the files created have the following characteristics.

1) The files mapped to zones of the same type are grouped together under a
   directory.
	* For conventional zones, the directory "cnv" is used.
	* For all sequential write zones, the directory "seq" is used.

2) The name of each file is by default the number of the file, corresponding to
   the number of the backing zone for the file. 

3) The size of conventional zone files is fixed to the zone size.
   Conventional zone files cannot be truncated.

4) The size of sequential zone files represent the zones write pointer
   position relative to the zone start sector. Truncating these files
   is allowed only down to a 0 size, in wich case, the zone is reset
   to rewind its write pointer position to the start of the zone.

5) All read and write operations to files are not allowed beyond the
   file zone size.

6) Creating, deleting, renaming etc files and directories is not allowed.

7) All files are by default owned by the root user with access permissions set
   to 640 ("-rw-r-----").

The on-disk super block allows specifying optional features which change the
default file system operation:

1) File names: the start sector value of a file backing zone can be used as a
   file name.

2) File owner UID and GID and access permissions can be changed.

3) Contiguous conventional zones can be aggregated into a single file instead
   of the default one file per zone.

## License

The *zonefs-tools* project source code is distributed under the terms of the
GNU General Public License v2.0 or later
([GPL-v2](https://opensource.org/licenses/GPL-2.0)).
A copy of this license with *zonefs-tools* copyright can be found in the files
[LICENSES/GPL-2.0-or-later.txt](LICENSES/GPL-2.0-or-later.txt) and
[COPYING.GPL](COPYING.GPL).

All source files in *zonefs-tools* contain the SPDX short identifier for the
GPL-2.0-or-later license in place of the full license text.

```
SPDX-License-Identifier: GPL-2.0-or-later
```

Some files such as the `Makefile.am` files and the `.gitignore` file are public
domain specified by the [CC0 1.0 Universal (CC0 1.0) Public Domain
Dedication](https://creativecommons.org/publicdomain/zero/1.0/).
These files are identified with the following SPDX short identifier header.

```
SPDX-License-Identifier: CC0-1.0
```

See [LICENSES/CC0-1.0.txt](LICENSES/CC0-1.0.txt) for the full text of this
license.

## Requirements

The following packages must be installed prior to compiling *mkzonefs*.

* autoconf
* autoconf-archive
* automake
* libtool
* libuuid library and its development headers (*libuuid* and *libuuid-devel*
  packages)
* libblkid library and its development headers (*libblkid* and *libblkid-devel*
  packages)

The kernel header file `/usr/include/linux/blkzoned.h` must also be present.

## Compilation and Installation

The following commands will compile the *mkzonefs* tool.

```
> sh ./autogen.sh
> ./configure
> make
```

To install the compiled executable files, simply execute as root the following
command.

```
> sudo make install
```

The default installation directory is /usr/sbin. This default location can be
changed using the configure script. Executing the following command displays
the options used to control the installation path.

```
> ./configure --help
```

## Usage

*mkzonefs* detailed usage is as follows:

```
> mkzonefs -h 
Usage: mkzonefs [options] <device path>
Options:
  --help | -h   : General help message
  -v            : Verbose output
  -f            : Force overwrite of existing content
  -o <features>	: Optional features
See "man mkzonefs" for more information
```

To format a zoned block device for use with *zonefs* with all default settings,
the following command can be used.

```
# mkzonefs /dev/<disk name>
```

Enabling optional features can be done with the *-o* option. For instance,
to set the files owner UID and GID to user "1000", the following command can
be used.

```
# mkzonefs -o uid=1000,gid=1000 /dev/<disk name>
```

Several optional features can be specified simultaneously as a comma separated
list. The following features are defined.

Feature       | Description
--------------|-------------------------------------------------
aggr_cnv | Aggregate contiguous conventional zones as a single file (default: off)
uid=*int* | Set zone files user owner ID (default: 0)
gid=*int* | Set zone files user group ID (default: 0)
perm=*octal* | Set zone files access permisisons (default: 640)

## Contributing

Read the [CONTRIBUTING](CONTRIBUTING) file and send patches to:

	Damien Le Moal <damien.lemoal@wdc.com>

If you believe your changes require kernel eyes or review, Cc the Linux kernel
file system development mailing list:

	linux-fsdevel@vger.kernel.org

