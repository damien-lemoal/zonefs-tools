// SPDX-License-Identifier: GPL-2.0-only
/*
 * Copyright (C) 2022 Western Digital Corporation or its affiliates.
 * Author: Damien Le Moal <damien.lemoal@opensource.wdc.com>
 */

#ifndef _GNU_SOURCE
#define _GNU_SOURCE
#endif

#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <unistd.h>
#include <errno.h>
#include <string.h>
#include <fcntl.h>
#include <signal.h>
#include <linux/limits.h>

#define ZOPEN_MAX_FILES		1024

struct zopen_params {
	bool		verbose;
	bool		pause;

	const char	*base_path;
	int		fflags;

	int		first_file;
	int		nr_files;
	int		fd[ZOPEN_MAX_FILES];
};

static void zopen_sigcatcher(int sig)
{
	return;
}

#define zopen_vprintf(zo,fmt,args...)		\
	if ((zo)->verbose) {			\
                printf(fmt, ## args);		\
        }

static int zopen(struct zopen_params *zo, int idx)
{
	char path[PATH_MAX];

	if (idx >= zo->nr_files) {
		fprintf(stderr, "Invalid file index %d/%d\n",
			idx, zo->nr_files);
		return -1;
	}

	/* Generate the file path */
	snprintf(path, sizeof(path) - 1, "%s/%d",
		 zo->base_path, zo->first_file + idx);

	zopen_vprintf(zo, "Opening %s\n", path);

	/* Open file */
	zo->fd[idx] = open(path, zo->fflags, 0);
	if (zo->fd[idx] < 0) {
		fprintf(stderr, "Open %s failed %d (%s)\n",
			path, errno, strerror(errno));
		return -1;
	}

	return 0;
}

static void zopen_usage(char *cmd)
{
	printf("Usage: %s [options] <path>\n",
	       cmd);
	printf("Options:\n"
	       "    -h | --help   : print usage and exit\n"
	       "    --v           : Verbose output\n"
	       "    --start=<n>   : First file to open (default: 0)\n"
	       "    --nrfiles=<n> : Number of files to open (default: 1)\n"
	       "    --fflag=<f>   : Use O_XXX to open files. <f> can be:\n"
	       "                      - read (default)\n"
	       "                      - write\n"
	       "                      - direct\n"
	       "                      - trunc\n"
	       "                    This option can be used multiple times.\n"
	       "    --pause       : Do not exit immediately and wait"
	       "                    for a signal\n");
}

int main(int argc, char **argv)
{
	struct zopen_params zo;
	const char *val;
	struct sigaction act;
	int i;

	/* Setup signal handler */
	act.sa_flags = 0;
	act.sa_handler = zopen_sigcatcher;
	sigemptyset(&act.sa_mask);
	(void)sigaction(SIGPIPE, &act, NULL);
	(void)sigaction(SIGINT, &act, NULL);
	(void)sigaction(SIGTERM, &act, NULL);

	/* Set default values */
	memset(&zo, 0, sizeof(struct zopen_params));
	zo.nr_files = 1;
	zo.fflags = O_LARGEFILE | O_RDONLY;
	for (i = 0; i < ZOPEN_MAX_FILES; i++)
		zo.fd[i] = -1;

	if (argc <= 1) {
		zopen_usage(argv[0]);
		return 1;
	}

	/* Parse command line */
	for (i = 1; i < argc; i++) {

		if (strcmp(argv[i], "-h") == 0 ||
		    strcmp(argv[i], "--help") == 0) {
			zopen_usage(argv[0]);
			return 0;
		}

		if (strcmp(argv[i], "--v") == 0) {

			zo.verbose = true;

		} else if (strncmp(argv[i], "--start=", 8) == 0) {

			zo.first_file = atoi(argv[i] + 8);
			if (zo.first_file < 0) {
				fprintf(stderr, "Invalid start file\n");
				return 1;
			}

		} else if (strncmp(argv[i], "--nrfiles=", 10) == 0) {

			zo.nr_files = atoi(argv[i] + 10);
			if (zo.nr_files <= 0 || zo.nr_files > ZOPEN_MAX_FILES) {
				fprintf(stderr, "Invalid number of files\n");
				return 1;
			}

		} else if (strncmp(argv[i], "--fflag=", 8) == 0) {

			val = argv[i] + 8;
			if (strcmp(val, "read") == 0) {
				zo.fflags |= O_RDONLY;
			} else if (strcmp(val, "write") == 0) {
				zo.fflags |= O_WRONLY;
			} else if (strcmp(val, "direct") == 0) {
				zo.fflags |= O_DIRECT;
			} else if (strcmp(val, "trunc") == 0) {
				zo.fflags |= O_TRUNC;
			} else {
				fprintf(stderr, "Invalid file open flag\n");
				return 1;
			}

		} else if (strcmp(argv[i], "--pause") == 0) {

			zo.pause = true;

		} else if (argv[i][0] == '-') {

			fprintf(stderr, "Invalid option \"%s\"\n", argv[i]);
			return 1;

		} else {

			break;

		}
	}

	if (i != argc - 1) {
		zopen_usage(argv[0]);
		return 0;
	}

	zo.base_path = realpath(argv[i], NULL);
	if (!zo.base_path) {
		fprintf(stderr, "Generate base path for %s failed\n", argv[i]);
		return 1;
	}

	/* Open files */
	for (i = 0; i < zo.nr_files; i++) {
		if (zopen(&zo, i))
			return 1;
	}

	printf("Opened %d file%s from file %d\n",
	       zo.nr_files, zo.nr_files > 1 ? "s" : "",
	       zo.first_file);

	if (zo.pause) {
		/* Wait for a signal */
		pause();
	}

	for (i = 0; i < zo.nr_files; i++)
		close(zo.fd[i]);

	printf("Closed %d file%s from file %d\n",
	       zo.nr_files, zo.nr_files > 1 ? "s" : "",
	       zo.first_file);

	return 0;
}
