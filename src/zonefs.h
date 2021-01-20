// SPDX-License-Identifier: GPL-2.0-or-later
/*
 * This file is part of zonefs tools.
 * Copyright (c) 2019 Western Digital Corporation or its affiliates.
 *
 * Authors: Damien Le Moal (damien.lemoal@wdc.com)
 */
#ifndef ZONEFS_H
#define ZONEFS_H

#define _LARGEFILE64_SOURCE

#include "config.h"

#include <limits.h>
#include <sys/types.h>
#include <linux/blkzoned.h>
#include <linux/magic.h>
#include <uuid/uuid.h>
#include <stdbool.h>

/*
 * On-disk super block magic.
 */
#ifndef ZONEFS_MAGIC
#define ZONEFS_MAGIC		0x5a4f4653 /* 'Z' 'O' 'F' 'S' */
#endif

/*
 * Feature flags.
 */
#define ZONEFS_F_AGGRCNV	(1ULL << 0)
#define ZONEFS_F_UID		(1ULL << 1)
#define ZONEFS_F_GID		(1ULL << 2)
#define ZONEFS_F_PERM		(1ULL << 3)

/*
 * Volume label and UUID size.
 */
#define ZONEFS_LABEL_LEN	64
#define ZONEFS_UUID_SIZE	16

/*
 * On disk super block.
 * This uses a full 4KB block.
 */
#define ZONEFS_SUPER_SIZE	4096U
struct zonefs_super {

	/* Magic number */
	__le32		s_magic;			/*    4 */

	/* Checksum */
	__le32		s_crc;				/*    8 */

	/* Volume label */
	char		s_label[ZONEFS_LABEL_LEN];	/*   72 */

	/* 128-bit uuid */
	__u8		s_uuid[ZONEFS_UUID_SIZE];	/*   88 */

	/* Features */
	__le64		s_features;			/*   96 */

	/* UID/GID to use for files */
	__le32		s_uid;				/*  100 */
	__le32		s_gid;				/*  104 */

	/* File permissions */
	__le32		s_perm;				/*  108 */

	/* Padding to ZONEFS_SUPER_SIZE bytes */
	__u8		s_reserved[3988];		/* 4096 */

} __attribute__ ((packed));

/*
 * Device descriptor.
 */
struct zonefs_dev {

	/* Device file path and basename */
	char			*path;
	char			*name;

	/* Flags and features */
	unsigned int		flags;
	unsigned long long	features;
	unsigned int		uid;
	unsigned int		gid;
	unsigned int		perm;
	char			label[ZONEFS_LABEL_LEN];
	uuid_t			uuid;

	/* Device info */
	unsigned int		model;
	unsigned long long	capacity;
	size_t			zone_nr_sectors;
	unsigned int		nr_zones;
	unsigned int		nr_conv_zones;
	unsigned int		nr_seq_zones;
	unsigned int		nr_ro_zones;
	unsigned int		nr_ol_zones;
	struct blk_zone		*zones;

	/* Device file descriptor */
	int			fd;

};

/*
 * Device model.
 */
#define ZONEFS_DEV_HM		1
#define ZONEFS_DEV_HA		2

/*
 * Device flags.
 */
#define ZONEFS_VERBOSE  	(1 << 0)
#define ZONEFS_OVERWRITE	(1 << 1)

#define zonefs_zone_id(dev, z) \
	(unsigned int)((z)->start / (dev)->zone_nr_sectors)

int zonefs_open_dev(struct zonefs_dev *dev, bool check_overwrite);
void zonefs_close_dev(struct zonefs_dev *dev);
int zonefs_sync_dev(struct zonefs_dev *dev);
int zonefs_finish_zone(struct zonefs_dev *dev, struct blk_zone *zone);
int zonefs_reset_zone(struct zonefs_dev *dev, struct blk_zone *zone);
int zonefs_reset_zones(struct zonefs_dev *dev);

/*
 * For compile time checks
 */
#define ZONEFS_STATIC_ASSERT(cond) \
	void zonefs_static_assert(int dummy[(cond) ? 1 : -1])

#endif /* ZONEFS_H */
