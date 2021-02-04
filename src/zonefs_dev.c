// SPDX-License-Identifier: GPL-2.0-or-later
/*
 * This file is part of zonefs tools.
 * Copyright (c) 2019 Western Digital Corporation or its affiliates.
 *
 * Authors: Damien Le Moal (damien.lemoal@wdc.com)
 */

#include "zonefs.h"

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <errno.h>
#include <libgen.h>
#include <assert.h>

#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <sys/ioctl.h>
#include <linux/fs.h>
#include <mntent.h>
#include <dirent.h>

#include <blkid/blkid.h>

/*
 * Test if the device is mounted.
 */
static int zonefs_dev_mounted(struct zonefs_dev *dev)
{
	struct mntent *mnt = NULL;
	FILE *file = NULL;

	file = setmntent("/proc/mounts", "r");
	if (file == NULL)
		return 0;

	while ((mnt = getmntent(file)) != NULL) {
		if (strcmp(dev->path, mnt->mnt_fsname) == 0)
			break;
	}
	endmntent(file);

	return mnt ? 1 : 0;
}

/*
 * Test if the device is already used as a target backend.
 */
static int zonefs_dev_busy(struct zonefs_dev *dev)
{
	char path[128];
	struct dirent **namelist;
	int n, ret = 0;

	snprintf(path, sizeof(path),
		 "/sys/block/%s/holders",
		 dev->name);

	n = scandir(path, &namelist, NULL, alphasort);
	if (n < 0) {
		fprintf(stderr, "scandir %s failed\n", path);
		return -1;
	}

	while (n--) {
		if (strcmp(namelist[n]->d_name, "..") != 0 &&
		    strcmp(namelist[n]->d_name, ".") != 0)
			ret = 1;
		free(namelist[n]);
	}
	free(namelist);

	return ret;
}

/*
 * Check that the device is a zoned block device.
 */
static bool zonefs_dev_is_zoned(struct zonefs_dev *dev)
{
	char str[PATH_MAX];
	FILE *file;
	int res;
	int len;

	/* Check that this is a zoned block device */
	len = snprintf(str, sizeof(str),
		       "/sys/block/%s/queue/zoned",
		       dev->name);

	/* Indicates truncation */
	if (len >= PATH_MAX) {
		fprintf(stderr, "name %s failed: %s\n", str,
			strerror(ENAMETOOLONG));
		return false;
	}

	file = fopen(str, "r");
	if (!file) {
		fprintf(stderr, "Open %s failed\n", str);
		return false;
	}

	memset(str, 0, sizeof(str));
	res = fscanf(file, "%s", str);
	fclose(file);

	if (res != 1) {
		fprintf(stderr, "Invalid file %s format\n", str);
		return false;
	}

	if (strcmp(str, "host-aware") == 0) {
		dev->model = ZONEFS_DEV_HA;
		return true;
	}

	if (strcmp(str, "host-managed") == 0) {
		dev->model = ZONEFS_DEV_HM;
		return true;
	}

	return false;
}

/*
 * Get device capacity and zone size.
 */
static int zonefs_get_dev_capacity(struct zonefs_dev *dev)
{
	char str[128];
	FILE *file;
	int res;

	/* Get capacity */
	if (ioctl(dev->fd, BLKGETSIZE64, &dev->capacity) < 0) {
		fprintf(stderr,
			"%s: Get capacity failed %d (%s)\n",
			dev->path, errno, strerror(errno));
		return -1;
	}
	dev->capacity >>= 9;

	/* Get zone size */
	snprintf(str, sizeof(str),
		 "/sys/block/%s/queue/chunk_sectors",
		 dev->name);
	file = fopen(str, "r");
	if (!file) {
		fprintf(stderr, "Open %s failed\n", str);
		return -1;
	}

	memset(str, 0, sizeof(str));
	res = fscanf(file, "%s", str);
	fclose(file);

	if (res != 1) {
		fprintf(stderr, "Invalid file %s format\n", str);
		return -1;
	}

	dev->zone_nr_sectors = atol(str);
	if (!dev->zone_nr_sectors) {
		fprintf(stderr,
			"%s: Invalid zone size\n",
			dev->path);
		return -1;
	}

	return 0;
}

/*
 * Convert zone type to a string.
 */
static inline const char *zonefs_zone_type_str(struct blk_zone *zone)
{
	switch (zone->type) {
	case BLK_ZONE_TYPE_CONVENTIONAL:
		return( "Conventional" );
	case BLK_ZONE_TYPE_SEQWRITE_REQ:
		return( "Sequential-write-required" );
	case BLK_ZONE_TYPE_SEQWRITE_PREF:
		return( "Sequential-write-preferred" );
	}
	return( "Unknown-type" );
}

/*
 * Convert zone condition to a string.
 */
static inline const char *zonefs_zone_cond_str(struct blk_zone *zone)
{
	switch (zone->cond) {
	case BLK_ZONE_COND_NOT_WP:
		return "Not-write-pointer";
	case BLK_ZONE_COND_EMPTY:
		return "Empty";
	case BLK_ZONE_COND_IMP_OPEN:
		return "Implicit-open";
	case BLK_ZONE_COND_EXP_OPEN:
		return "Explicit-open";
	case BLK_ZONE_COND_CLOSED:
		return "Closed";
	case BLK_ZONE_COND_READONLY:
		return "Read-only";
	case BLK_ZONE_COND_FULL:
		return "Full";
	case BLK_ZONE_COND_OFFLINE:
		return "Offline";
	}
	return "Unknown-condition";
}

/*
 * Print a device zone information.
 */
static void zonefs_print_zone(struct zonefs_dev *dev, struct blk_zone *zone)
{

	if (zone->cond == BLK_ZONE_COND_READONLY) {
		printf("Zone %05u: readonly %s zone\n",
		       zonefs_zone_id(dev, zone),
		       zonefs_zone_type_str(zone));
		return;
	}

	if (zone->cond == BLK_ZONE_COND_OFFLINE) {
		printf("Zone %05u: offline %s zone\n",
		       zonefs_zone_id(dev, zone),
		       zonefs_zone_type_str(zone));
		return;
	}

	if (zone->type == BLK_ZONE_TYPE_CONVENTIONAL) {
		printf("Zone %05u: Conventional, sector %llu, %llu sectors\n",
		       zonefs_zone_id(dev, zone),
		       zone->start, zone->len);
		return;
	}

	printf("Zone %05u: type 0x%x (%s), cond 0x%x (%s), "
	       "sector %llu, %llu sectors, wp sector %llu\n",
	       zonefs_zone_id(dev, zone),
	       zone->type, zonefs_zone_type_str(zone),
	       zone->cond, zonefs_zone_cond_str(zone),
	       zone->start, zone->len, zone->wp);
}

#define ZONEFS_REPORT_ZONES_BUFSZ	524288

/*
 * Get a device zone configuration.
 */
static int zonefs_get_dev_zones(struct zonefs_dev *dev)
{
	struct blk_zone_report *rep = NULL;
	unsigned int rep_max_zones;
	struct blk_zone *blkz;
	unsigned int i, nr_zones;
	__u64 sector;
	int ret = -1;

	/* This will ignore an eventual last smaller zone */
	nr_zones = dev->capacity / dev->zone_nr_sectors;
	if (dev->capacity % dev->zone_nr_sectors)
		nr_zones++;

	/* Allocate zone array */
	dev->zones = calloc(nr_zones, sizeof(struct blk_zone));
	if (!dev->zones) {
		fprintf(stderr, "Not enough memory\n");
		return -1;
	}

	/* Get a buffer for zone report */
	rep = malloc(ZONEFS_REPORT_ZONES_BUFSZ);
	if (!rep) {
		fprintf(stderr, "Not enough memory\n");
		goto out;
	}
	rep_max_zones =
		(ZONEFS_REPORT_ZONES_BUFSZ - sizeof(struct blk_zone_report))
		/ sizeof(struct blk_zone);

	sector = 0;
	while (sector < dev->capacity) {

		/* Get zone information */
		memset(rep, 0, ZONEFS_REPORT_ZONES_BUFSZ);
		rep->sector = sector;
		rep->nr_zones = rep_max_zones;
		ret = ioctl(dev->fd, BLKREPORTZONE, rep);
		if (ret != 0) {
			fprintf(stderr,
				"%s: Get zone information failed %d (%s)\n",
				dev->name, errno, strerror(errno));
			goto out;
		}

		if (!rep->nr_zones)
			break;

		blkz = (struct blk_zone *)(rep + 1);
		for (i = 0; i < rep->nr_zones && sector < dev->capacity; i++) {

			if (dev->flags & ZONEFS_VERBOSE)
				zonefs_print_zone(dev, blkz);

			/* Check zone size */
			if (blkz->len != dev->zone_nr_sectors &&
			    blkz->start + blkz->len != dev->capacity) {
				fprintf(stderr,
					"%s: Invalid zone %u size\n",
					dev->name,
					zonefs_zone_id(dev, blkz));
				ret = -1;
				goto out;
			}

			dev->zones[dev->nr_zones] = *blkz;
			dev->nr_zones++;

			if (blkz->cond == BLK_ZONE_COND_READONLY)
				dev->nr_ro_zones++;
			else if (blkz->cond == BLK_ZONE_COND_OFFLINE)
				dev->nr_ol_zones++;

			if (blkz->type == BLK_ZONE_TYPE_CONVENTIONAL)
				dev->nr_conv_zones++;
			else
				dev->nr_seq_zones++;

			sector = blkz->start + blkz->len;
			blkz++;

		}

	}

	if (sector != dev->capacity) {
		fprintf(stderr,
			"%s: Invalid zones (last sector reported is %llu, "
			"expected %llu)\n",
			dev->name,
			sector, dev->capacity);
		ret = -1;
		goto out;
	}

	if (dev->nr_zones != nr_zones) {
		fprintf(stderr,
			"%s: Invalid number of zones (expected %u, got %u)\n",
			dev->name,
			nr_zones, dev->nr_zones);
		ret = -1;
		goto out;
	}

out:
	free(rep);

	return ret;
}

/*
 * Get a device information.
 */
static int zonefs_get_dev_info(struct zonefs_dev *dev)
{
	if (!zonefs_dev_is_zoned(dev)) {
		fprintf(stderr,
			"%s: Not a zoned block device\n",
			dev->name);
		return -1;
	}

	if (zonefs_get_dev_capacity(dev) < 0)
		return -1;

	if (zonefs_get_dev_zones(dev) < 0)
		return -1;

	return 0;
}

/*
 * Use libblkid to check for existing file systems on the device.
 * Return -1 on error, 0 if something valid is detected on the device
 * and 1 if the device appears to be unused.
 */
static int zonefs_check_overwrite(struct zonefs_dev *dev)
{
	const char *type;
	blkid_probe pr;
	int ret = -1;

	pr = blkid_new_probe_from_filename(dev->path);
	if (!pr)
		goto out;

	ret = blkid_probe_enable_superblocks(pr, 1);
	if (ret < 0)
		goto out;

	ret = blkid_probe_enable_partitions(pr, 1);
	if (ret < 0)
		goto out;

	ret = blkid_do_fullprobe(pr);
	if (ret < 0 || ret == 1) {
		/* 1 means that nothing was found */
		goto out;
	}

	/* Analyze what was found on the device */
	ret = blkid_probe_lookup_value(pr, "TYPE", &type, NULL);
	if (ret == 0) {
		fprintf(stderr,
			"%s appears to contain an existing filesystem (%s)\n",
			dev->path, type);
		goto out;
	}

	ret = blkid_probe_lookup_value(pr, "PTTYPE", &type, NULL);
	if (ret == 0) {
		fprintf(stderr,
			"%s appears to contain a partition table (%s)\n",
			dev->path, type);
		goto out;
	}

	fprintf(stderr,
		"%s appears to contain something according to blkid\n",
		dev->path);
	ret = 0;

out:
	if (pr)
		blkid_free_probe(pr);

	if (ret == 0)
		fprintf(stderr, "Use the option '-f' to overwrite\n");
	else if (ret < 0)
		fprintf(stderr,
			"%s: probe failed, cannot detect existing filesystem\n",
			dev->name);

	return ret;
}

/*
 * Open a device.
 */
int zonefs_open_dev(struct zonefs_dev *dev, bool check_overwrite)
{
	struct stat st;
	int ret;

	dev->name = basename(dev->path);

	/* Check that this is a block device */
	if (stat(dev->path, &st) < 0) {
		fprintf(stderr,
			"Get %s stat failed %d (%s)\n",
			dev->path,
			errno, strerror(errno));
		return -1;
	}

	if (!S_ISBLK(st.st_mode)) {
		fprintf(stderr,
			"%s is not a block device\n",
			dev->path);
		return -1;
	}

	if (check_overwrite && !(dev->flags & ZONEFS_OVERWRITE)) {
		/* Check for existing valid content */
		ret = zonefs_check_overwrite(dev);
		if (ret <= 0)
			return -1;
	}

	if (zonefs_dev_mounted(dev)) {
		fprintf(stderr,
			"%s is mounted\n",
			dev->path);
		return -1;
	}

	if (zonefs_dev_busy(dev)) {
		fprintf(stderr,
			"%s is in use\n",
			dev->path);
		return -1;
	}

	/* Open device */
	dev->fd = open(dev->path, O_RDWR | O_DIRECT);
	if (dev->fd < 0) {
		fprintf(stderr,
			"Open %s failed %d (%s)\n",
			dev->path,
			errno, strerror(errno));
		return -1;
	}

	/* Get device capacity and zone configuration */
	if (zonefs_get_dev_info(dev) < 0) {
		zonefs_close_dev(dev);
		return -1;
	}

	return 0;
}

/*
 * Close an open device.
 */
void zonefs_close_dev(struct zonefs_dev *dev)
{
	if (dev->fd >= 0) {
		close(dev->fd);
		dev->fd = -1;
	}

	free(dev->zones);
	dev->zones = NULL;
}

/*
 * Write a metadata block.
 */
int zonefs_sync_dev(struct zonefs_dev *dev)
{
	blkid_cache cache;
	int ret;

	ret = fsync(dev->fd);
	if (ret < 0) {
		fprintf(stderr,
			"%s: fsync failed %d (%s)\n",
			dev->name,
			errno, strerror(errno));
		return -1;
	}

	/*
	 * Make sure udev notices the uuid and label changes so that blkid
	 * cache and by-uuid/by-label device links all get updated.
	 */
	ret = blkid_get_cache(&cache, NULL);
	if (ret >= 0) {
		blkid_get_dev(cache, dev->path, BLKID_DEV_NORMAL);
		blkid_put_cache(cache);
	}
	blkid_send_uevent(dev->path, "change");

	return 0;
}

/*
 * Finish a zone (requires Linux kernel v5.5 and above).
 */
#ifdef BLKFINISHZONE

int zonefs_finish_zone(struct zonefs_dev *dev, struct blk_zone *zone)
{
	struct blk_zone_range range;

	if (zone->type == BLK_ZONE_TYPE_CONVENTIONAL)
		return 0;

	/* Sequential zone: transition it to full state */
	range.sector = zone->start;
	range.nr_sectors = zone->len;
	if (ioctl(dev->fd, BLKFINISHZONE, &range) < 0) {
		fprintf(stderr,
			"%s: Finish zone %u failed %d (%s)\n",
			dev->name, zonefs_zone_id(dev, zone),
			errno, strerror(errno));
		return -1;
	}

	return 0;
}
#else

int zonefs_finish_zone(struct zonefs_dev *dev, struct blk_zone *zone)
{
	return 0;
}

#endif /* BLKFINISHZONE */

/*
 * Reset a zone.
 */
static int zonefs_reset_zone(struct zonefs_dev *dev, struct blk_zone *zone)
{
	struct blk_zone_range range;

	if (zone->type == BLK_ZONE_TYPE_CONVENTIONAL)
		return 0;

	/* Sequential zone: reset */
	range.sector = zone->start;
	range.nr_sectors = zone->len;
	if (ioctl(dev->fd, BLKRESETZONE, &range) < 0) {
		fprintf(stderr,
			"%s: Reset zone %u failed %d (%s)\n",
			dev->name, zonefs_zone_id(dev, zone),
			errno, strerror(errno));
		return -1;
	}

	zone->wp = zone->start;

	return 0;
}

/*
 * Reset all zones of a device.
 */
int zonefs_reset_zones(struct zonefs_dev *dev)
{
	struct blk_zone_range range;
	unsigned int i;
	int ret;

	/*
	 * Try to reset all zones. This does not work on all devices so if
	 * this fails, fall back to resetting zones one at a time.
	 */
	range.sector = 0;
	range.nr_sectors = dev->capacity;
	ret = ioctl(dev->fd, BLKRESETZONE, &range);
	if (!ret) {
		for (i = 0; i < dev->nr_zones; i++)
			dev->zones[i].wp = dev->zones[i].start;
		return 0;
	}

	/* Fallback to zone reset zones one at a time */
	for (i = 0; i < dev->nr_zones; i++) {
		ret = zonefs_reset_zone(dev, &dev->zones[i]);
		if (ret)
			return ret;
	}

	return 0;
}
