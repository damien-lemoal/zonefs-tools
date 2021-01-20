// SPDX-License-Identifier: GPL-2.0-or-later
/*
 * This file is part of zonefs tools.
 * Copyright (c) 2019 Western Digital Corporation or its affiliates.
 *
 * Authors: Damien Le Moal (damien.lemoal@wdc.com)
 */

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <errno.h>
#include <limits.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <asm/byteorder.h>

#include "zonefs.h"

/*
 * For super block checksum (CRC32)
 */
#define CRCPOLY_LE 0xedb88320

__u32 zonefs_crc32(__u32 crc, const void *buf, size_t length)
{
        unsigned char *p = (unsigned char *)buf;
        int i;

        while (length--) {
                crc ^= *p++;
                for (i = 0; i < 8; i++)
                        crc = (crc >> 1) ^ ((crc & 1) ? CRCPOLY_LE : 0);
        }

        return crc;
}

/*
 * Fill and write a super block.
 */
static int zonefs_write_super(struct zonefs_dev *dev)
{
	struct zonefs_super *super;
	__u32 crc;
	int ret;

	ret = posix_memalign((void **)&super, sysconf(_SC_PAGESIZE),
			     sizeof(*super));
	if (ret) {
		fprintf(stderr, "Not enough memory\n");
		return -1;
	}

	memset(super, 0, sizeof(*super));
	super->s_magic = __cpu_to_le32(ZONEFS_MAGIC);
	uuid_copy(super->s_uuid, dev->uuid);
	strcpy(super->s_label, dev->label);
	super->s_features = __cpu_to_le64(dev->features);
	super->s_uid = __cpu_to_le32(dev->uid);
	super->s_gid = __cpu_to_le32(dev->gid);
	super->s_perm = __cpu_to_le32(dev->perm);

	crc = zonefs_crc32(~0U, super, sizeof(*super));
	super->s_crc = __cpu_to_le32(crc);

	ret = pwrite(dev->fd, super, sizeof(*super), 0);
	free(super);

	if (ret < 0) {
		fprintf(stderr,
			"%s: Write super block failed %d (%s)\n",
			dev->name, errno, strerror(errno));
		return -1;
	}

	return zonefs_finish_zone(dev, &dev->zones[0]);
}

/*
 * Parse features string.
 */
static int zonefs_parse_features(struct zonefs_dev *dev, char *features)
{
	char *ef, *f = features;

	while (*f) {

		if (strncmp(f, "aggr_cnv", 8) == 0) {
			dev->features |= ZONEFS_F_AGGRCNV;
			f += 8;
		} else if (strncmp(f, "uid=", 4) == 0) {
			dev->features |= ZONEFS_F_UID;
			f += 4;
			dev->uid = strtol(f, &ef, 10);
			if (errno == ERANGE) {
				fprintf(stderr, "Invalid UID\n");
				return -1;
			}
			f = ef;
		} else if (strncmp(f, "gid=", 4) == 0) {
			dev->features |= ZONEFS_F_GID;
			f += 4;
			dev->gid = strtol(f, &ef, 10);
			if (errno == ERANGE) {
				fprintf(stderr, "Invalid GID\n");
				return -1;
			}
			f = ef;
		} else if (strncmp(f, "perm=", 5) == 0) {
			dev->features |= ZONEFS_F_PERM;
			f += 5;
			dev->perm = strtol(f, &ef, 8);
			if (errno == ERANGE) {
				fprintf(stderr, "Invalid file permissions\n");
				return -1;
			}
			f = ef;
		}

		if (*f) {
			if (*f != ',') {
				fprintf(stderr, "Invalid feature string\n");
				return -1;
			}
			f++;
		}
	}

	return 0;
}

/*
 * Print usage.
 */
static void mkzonefs_usage(void)
{
	printf("Usage: mkzonefs [options] <device path>\n");
	printf("Options:\n"
	       "  --version     : Print version number and exit\n"
	       "  --help | -h   : General help message\n"
	       "  -v            : Verbose output\n"
	       "  -f            : Force overwrite of existing content\n"
	       "  -o <features>	: Optional features\n");
}

/*
 * Main function.
 */
int main(int argc, char **argv)
{
	unsigned int nr_zones;
	struct zonefs_dev dev;
	char uuid_str[UUID_STR_LEN];
	int i, ret;

	/* Compile time checks */
	ZONEFS_STATIC_ASSERT(sizeof(struct zonefs_super) == ZONEFS_SUPER_SIZE);
	ZONEFS_STATIC_ASSERT(sizeof(uuid_t) == ZONEFS_UUID_SIZE);

	/* Initialize */
	memset(&dev, 0, sizeof(dev));
	dev.fd = -1;

	/* Defaults */
	dev.uid = 0;	/* root */
	dev.gid = 0; /* root */
	dev.perm = S_IRUSR | S_IWUSR | S_IRGRP; /* 0640 */

	/* Parse options */
	for (i = 1; i < argc; i++) {
		if (strcmp(argv[i], "--version") == 0) {
			printf("mkzonefs, version %s\n", PACKAGE_VERSION);
			printf("Copyright (C) 2019, Western Digital Corporation"
			       " or its affiliates.\n");
			return 0;
		}

		if (strcmp(argv[i], "--help") == 0 ||
		    strcmp(argv[i], "-h") == 0) {
			mkzonefs_usage();
			printf("See \"man mkzonefs\" for more information\n");
			return 0;
		}

		if (strcmp(argv[i], "-f") == 0) {
			dev.flags |= ZONEFS_OVERWRITE;
		} else if (strcmp(argv[i], "-v") == 0) {
			dev.flags |= ZONEFS_VERBOSE;
		} else if (strcmp(argv[i], "-L") == 0) {
			i++;
			if (i >= argc - 1) {
				fprintf(stderr, "Invalid command line\n");
				return 1;
			}
			if (strlen(argv[i]) > ZONEFS_LABEL_LEN) {
				fprintf(stderr,
					"Label too long (%d chars allowed)\n",
					ZONEFS_LABEL_LEN);
				return 1;
			}
			memcpy(dev.label, argv[i], strlen(argv[i]));
		} else if (strcmp(argv[i], "-o") == 0) {
			i++;
			if (i >= argc - 1) {
				fprintf(stderr, "Invalid command line\n");
				return 1;
			}
			if (zonefs_parse_features(&dev, argv[i]) < 0)
				return 1;
		} else if (argv[i][0] == '-') {
			fprintf(stderr, "Invalid option '%s'\n", argv[i]);
			return 1;
		} else {
			break;
		}
	}

	if (i != argc - 1) {
		fprintf(stderr, "No device specified\n");
		return 1;
	}

	/* Get device path */
	dev.path = realpath(argv[i], NULL);
	if (!dev.path) {
		fprintf(stderr, "Failed to get device real path\n");
		return 1;
	}

	/* Open the device */
	if (zonefs_open_dev(&dev, true) < 0)
		return 1;

	printf("%s: %llu 512-byte sectors (%llu GiB)\n",
	       dev.path,
	       dev.capacity,
	       (dev.capacity << 9) / (1024ULL * 1024ULL * 1024ULL));
	printf("  Host-%s device\n",
	       (dev.model == ZONEFS_DEV_HM) ? "managed" : "aware");
	nr_zones = dev.capacity / dev.zone_nr_sectors;
	printf("  %u zones of %zu 512-byte sectors (%zu MiB)\n",
	       nr_zones,
	       dev.zone_nr_sectors,
	       (dev.zone_nr_sectors << 9) / (1024 * 1024));
	if (nr_zones < dev.nr_zones) {
		size_t runt_sectors = dev.capacity & (dev.zone_nr_sectors - 1);

		printf("  1 runt zone of %zu 512-byte sectors (%zu MiB)\n",
		       runt_sectors,
		       (runt_sectors << 9) / (1024 * 1024));
	}
	printf("  %u conventional zones, %u sequential zones\n",
	       dev.nr_conv_zones, dev.nr_seq_zones);
	printf("  %u read-only zones, %u offline zones\n",
	       dev.nr_ro_zones, dev.nr_ol_zones);

	if (dev.nr_ol_zones >= dev.nr_zones - 1) {
		fprintf(stderr, "No useable zones\n");
		ret = 1;
		goto out;
	}

	printf("Format:\n");
	printf("  %u usable zones\n", dev.nr_zones - dev.nr_ol_zones - 1);
	printf("  Aggregate conventional zones: %s\n",
	       dev.features & ZONEFS_F_AGGRCNV ? "enabled" : "disabled");
	printf("  File UID: %u\n", dev.uid);
	printf("  File GID: %u\n", dev.gid);
	printf("  File access permissions: %o\n", dev.perm);

	if (strlen(dev.label))
		printf("  FS label: %s\n", dev.label);

	uuid_generate(dev.uuid);
	uuid_unparse(dev.uuid, uuid_str);
	printf("  FS UUID: %s\n", uuid_str);

	ret = 1;

	printf("Resetting sequential zones\n");
	if (zonefs_reset_zones(&dev) < 0)
		goto out;

	printf("Writing super block\n");
	if (zonefs_write_super(&dev) < 0)
		goto out;

	/* Sync */
	if (zonefs_sync_dev(&dev) < 0)
		goto out;

	ret = 0;

out:
	zonefs_close_dev(&dev);

	return ret;
}

