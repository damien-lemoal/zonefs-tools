// SPDX-License-Identifier: GPL-2.0-only
/*
 * Copyright (C) 2019 Western Digital Corporation or its affiliates.
 * Author: Damien Le Moal <damien.lemoal@wdc.com>
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
#include <sys/types.h>
#include <sys/time.h>
#include <sys/stat.h>
#include <sys/uio.h>
#include <sys/syscall.h>
#include <fcntl.h>
#include <linux/aio_abi.h>
#include <linux/fs.h>

/*
 * IO descriptor.
 */
struct zio {
	int nr;
	void *buf;
        struct iocb iocb;
};

/*
 * Run parameters.
 */
struct zio_params {
	bool verbose;
	int fd;

	bool read;
	bool async;

	int fflags;
	bool append;
	loff_t fsize;
	loff_t fmaxsize;

	size_t iosize;
	loff_t ioofst;
	unsigned int ionum;
	int ioflags;
	unsigned int iodepth;
	struct zio *io;

	aio_context_t ioctx;
        struct iocb **iocbs;

	unsigned int nr_ios;
};

/*
 * Utilities.
 */
#define zio_vprintf(zio,format,args...)		\
	if ((zio)->verbose) {			\
                printf(format, ## args);	\
        }

static inline unsigned long long zio_usec(void)
{
	struct timeval tv;

	gettimeofday(&tv, NULL);

	return tv.tv_sec * 1000000ULL + tv.tv_usec;
}

/*
 * System call wrappers.
 */
ssize_t preadv2(int fd, const struct iovec *iov, int iovcnt,
		off_t offset, int flags)
{
	return syscall(SYS_preadv2, fd, iov, iovcnt, offset, 0, flags);
}

ssize_t pwritev2(int fd, const struct iovec *iov, int iovcnt,
		 off_t offset, int flags)
{
	return syscall(SYS_pwritev2, fd, iov, iovcnt, offset, 0, flags);
}

static inline int io_setup(unsigned int nr, aio_context_t *ctxp)
{
	return syscall(__NR_io_setup, nr, ctxp);
}

static inline int io_destroy(aio_context_t ctx)
{
	return syscall(__NR_io_destroy, ctx);
}

static inline int io_submit(aio_context_t ctx, long nr, struct iocb **iocbpp)
{
	return syscall(__NR_io_submit, ctx, nr, iocbpp);
}

static inline int io_getevents(aio_context_t ctx, long min_nr, long max_nr,
			       struct io_event *events,
			       struct timespec *timeout)
{
	return syscall(__NR_io_getevents, ctx, min_nr, max_nr, events, timeout);
}

static inline bool zio_done(struct zio_params *zio)
{
	if (zio->ionum)
		return zio->nr_ios >= zio->ionum;

	return (zio->read && zio->ioofst >= zio->fsize) ||
		(!zio->read && zio->ioofst >= zio->fmaxsize);
}

/*
 * Sync IO run.
 */
static int zio_run_sync(struct zio_params *zio)
{
	ssize_t ret;
	loff_t ofst;
	struct iovec iov = {
		.iov_base = zio->io[0].buf,
		.iov_len = zio->iosize,
	};

	while (!zio_done(zio)) {

		if (zio->read) {
			ofst = zio->ioofst;
			ret = preadv2(zio->fd, &iov, 1, ofst, zio->ioflags);
		} else {
			if (zio->append)
				ofst = 0;
			else
				ofst = zio->ioofst;
			ret = pwritev2(zio->fd, &iov, 1, ofst, zio->ioflags);
		}
		if (ret <= 0) {
			fprintf(stderr, "%05u: %s %zu B at %ld failed %d (%s)\n",
				zio->nr_ios,
				zio->read ? "READ" : "WRITE",
				zio->iosize, zio->ioofst,
				errno, strerror(errno));
			return errno;
		}

		zio_vprintf(zio, "%05u: %s %zu B at %ld\n",
			    zio->nr_ios,
			    zio->read ? "READ" : "WRITE",
			    zio->iosize, zio->ioofst);

		zio->nr_ios++;
		zio->ioofst += ret;
	}

	return 0;
}

/*
 * Async IO run.
 */
static int zio_submit_async(struct zio_params *zio)
{
	struct iocb *iocb;
	struct zio *io;
	unsigned int i, n = 0;
	int ret;

	for (i = 0; i < zio->iodepth; i++) {
		if (zio_done(zio))
			break;

		io = &zio->io[i];
		if (io->nr >= 0)
			continue;

		iocb = &io->iocb;
		memset(iocb, 0, sizeof(struct iocb));
		iocb->aio_fildes = zio->fd;
		if (zio->read) {
			iocb->aio_lio_opcode = IOCB_CMD_PREAD;
			iocb->aio_offset = zio->ioofst;
		} else {
			iocb->aio_lio_opcode = IOCB_CMD_PWRITE;
			if (zio->append)
				iocb->aio_offset = 0;
			else
				iocb->aio_offset = zio->ioofst;
		}
		iocb->aio_buf = (unsigned long)io->buf;
		iocb->aio_nbytes = zio->iosize;
		iocb->aio_rw_flags = zio->ioflags;
		iocb->aio_data = (unsigned long)io;

		io->nr = zio->nr_ios;

		zio_vprintf(zio, "%05d: %s %zu B at %ld issued\n",
			    io->nr,
			    zio->read ? "READ" : "WRITE",
			    zio->iosize, zio->ioofst);

		zio->iocbs[n] = iocb;
		n++;
		zio->nr_ios++;

		zio->ioofst += zio->iosize;
	}

	if (!n)
		return 0;

	ret = io_submit(zio->ioctx, n, zio->iocbs);
	if (ret < 0) {
		fprintf(stderr, "io_submit failed %d (%s)\n",
			errno, strerror(errno));
		return -1;
	}

	return n;
}

static int zio_check_async(struct zio_params *zio,
			   int submitted, int in_flight)
{
	struct io_event ioevent;
	struct iocb *iocb;
	struct zio *io;
	int ret, min_nr, n = 0;

	while (n < in_flight) {

		if (!submitted || (in_flight - n) >= (int)zio->iodepth)
			min_nr = 1;
		else
			min_nr = 0;

		ret = io_getevents(zio->ioctx, min_nr, 1, &ioevent, NULL);
		if (!ret)
			break;

		if (ret != 1) {
			fprintf(stderr, "io_getevents failed %d (%s)\n",
				ret, strerror(ret));
			return -1;
		}

		iocb = (struct iocb *) ioevent.obj;
		io = (struct zio *)ioevent.data;

		if (ioevent.res < 0) {
			ret = -ioevent.res;
			fprintf(stderr, "%05d: %s %llu B at %lld failed %d (%s)\n",
				io->nr,
				zio->read ? "READ" : "WRITE",
				iocb->aio_nbytes, iocb->aio_offset,
				ret, strerror(ret));
			return -1;
		}

		zio_vprintf(zio, "%05d: %s %llu B at %lld completed\n",
			    io->nr,
			    zio->read ? "READ" : "WRITE",
			    iocb->aio_nbytes, iocb->aio_offset);

		io->nr = -1;
		n++;
	}

	return n;
}

static int zio_run_async(struct zio_params *zio)
{
	struct io_event ioevent;
	int n, in_flight = 0;
	ssize_t ret;

	/* Setup IO context */
	memset(&zio->ioctx, 0, sizeof(aio_context_t));
	memset(&ioevent, 0, sizeof(struct io_event));
	ret = io_setup(zio->iodepth, &zio->ioctx);
        if (ret < 0) {
                fprintf(stderr, "io_setup failed %d (%s)\n",
			errno, strerror(errno));
                return -1;
        }

	/* Do IOs until submission stops */
	while (1) {

		n = zio_submit_async(zio);
		if (n < 0) {
			ret = -1;
			break;
		}

		if (!n && !in_flight)
			break;

		in_flight += n;

		n = zio_check_async(zio, n, in_flight);
		if (n < 0) {
			ret = -1;
			break;
		}

		in_flight -= n;
	}

	io_destroy(zio->ioctx);

	return ret;
}

static void zio_cleanup(struct zio_params *zio)
{
	unsigned int i;

	if (!zio->io)
		return;

	for (i = 0; i < zio->iodepth; i++)
		free(zio->io[i].buf);
	free(zio->io);
	zio->io = NULL;

	free(zio->iocbs);
	zio->iocbs = NULL;

	if (zio->fd > 0) {
		close(zio->fd);
		zio->fd = -1;
	}
}

static int zio_init(struct zio_params *zio, char *path)
{
	struct stat st;
	unsigned int i;
	int ret;

	/* Allocate and initialize IO array */
	zio->io = calloc(zio->iodepth, sizeof(struct zio));
	if (!zio->io) {
		fprintf(stderr, "No memory for IO array\n");
		return -1;
	}

	for (i = 0; i < zio->iodepth; i++) {
		zio->io[i].nr = -1;
		ret = posix_memalign((void **) &zio->io[i].buf,
				     sysconf(_SC_PAGESIZE), zio->iosize);
		if (ret != 0) {
			fprintf(stderr, "Allocate IO buffer failed %d (%s)\n",
				-ret, strerror(-ret));
			goto err;
		}
	}

	zio->iocbs = calloc(zio->iodepth, sizeof(struct iocb *));
	if (!zio->iocbs) {
		fprintf(stderr, "No memory for async IO array\n");
		goto err;
	}

	/* Open file */
	zio->fd = open(path, zio->fflags, 0);
	if (zio->fd < 0) {
		fprintf(stderr, "Open %s failed %d (%s)\n",
			path, errno, strerror(errno));
		goto err;
	}

	ret = fstat(zio->fd, &st);
	if (ret) {
		fprintf(stderr, "Stat %s failed %d (%s)\n",
			path, errno, strerror(errno));
		goto err;
	}
	zio->fsize = st.st_size;
	zio->fmaxsize = st.st_blocks << 9;

	/* If we do append writes, set offset to EOF */
	if (!zio->read) {
		zio->append =
			((zio->fflags & O_APPEND) == O_APPEND) ||
			(zio->ioflags & RWF_APPEND) == RWF_APPEND;
		if (zio->append)
			zio->ioofst = zio->fsize;
	}

	return 0;

err:
	zio_cleanup(zio);
	return -1;
}

static void zio_usage(char *cmd)
{
	printf("Usage: %s [options] <file path>\n",
	       cmd);
	printf("Options:\n"
	       "    -h | --help     : print usage and exit\n"
	       "    --v             : Verbose output (stats)\n"
	       "    --vv            : Very verbose output (IOs)\n"
	       "    --read          : do read (default)\n"
	       "    --write         : do write\n"
	       "    --size=<bytes>  : Do <bytes> sized IOs (default: 4096)\n"
	       "    --ofst=<bytes>  : Start IOs at <offset> (default: 0)\n"
	       "    --nio=<num>     : Do <num> IOs and exit\n"
	       "                       (default: IOs until EOF)\n"
	       "    --async=<depth> : Do asynchronous IOs, issuing at most\n"
	       "                       <depth> IOs at a time\n"
	       "    --fflag=<flag>  : Use O_<flag> to open file.\n"
	       "                      <flag> can be:\n"
	       "                        - direct\n"
	       "                        - append\n"
	       "                        - ndelay\n"
	       "                        - sync\n"
	       "                        - trunc\n"
	       "                      This option can be used multiple times.\n"
	       "    --ioflag=<flag> : Use RWF_<flag> for IOs. <flag> can be:\n"
	       "                        - nowait\n"
	       "                        - hipri\n"
	       "                        - append\n"
	       "                      This option can be used multiple times.\n");
}

int main(int argc, char **argv)
{
	struct zio_params zio;
	unsigned long long start;
	long long arg;
	int ret, i;

	/* Set default values */
	memset(&zio, 0, sizeof(struct zio_params));
	zio.fd = -1;
	zio.read = true;
	zio.async = false;
	zio.append = false;
	zio.fflags = O_LARGEFILE;
	zio.iosize = 4096;
	zio.iodepth = 1;
	zio.verbose = false;

	if (argc <= 1) {
		zio_usage(argv[0]);
		return 1;
	}

	/* Parse command line */
	for (i = 1; i < argc; i++) {

		if (strcmp(argv[i], "-h") == 0 ||
		    strcmp(argv[i], "--help") == 0) {
			zio_usage(argv[0]);
			return 0;
		}

		if (strcmp(argv[i], "--v") == 0) {
			zio.verbose = true;
		} else if (strcmp(argv[i], "--read") == 0) {
			zio.read = true;
			zio.fflags |= O_RDONLY;
		} else if (strcmp(argv[i], "--write") == 0) {
			zio.read = false;
			zio.fflags |= O_WRONLY;
		} else if (strncmp(argv[i], "--size=", 7) == 0) {
			arg = atol(argv[i] + 7);
			if (arg <= 0) {
				fprintf(stderr, "Invalid IO size\n");
				return 1;
			}
			zio.iosize = arg;
		} else if (strncmp(argv[i], "--ofst=", 7) == 0) {
			arg = atoll(argv[i] + 7);
			if (arg < 0) {
				fprintf(stderr, "Invalid IO offset\n");
				return 1;
			}
			zio.ioofst = arg;
		} else if (strncmp(argv[i], "--nio=", 6) == 0) {
			arg = atoi(argv[i] + 6);
			if (arg <= 0) {
				fprintf(stderr, "Invalid number of IOs\n");
				return 1;
			}
			zio.ionum = arg;
		} else if (strncmp(argv[i], "--async=", 8) == 0) {
			zio.async = true;
			arg = atoi(argv[i] + 8);
			if (arg <= 0) {
				fprintf(stderr, "Invalid async IO depth\n");
				return 1;
			}
			zio.iodepth = arg;
		} else if (strncmp(argv[i], "--fflag=", 8) == 0) {
			if (strcmp(argv[i] + 8, "direct") == 0) {
				zio.fflags |= O_DIRECT;
			} else if (strcmp(argv[i] + 8, "append") == 0) {
				zio.fflags |= O_APPEND;
			} else if (strcmp(argv[i] + 8, "ndelay") == 0) {
				zio.fflags |= O_NDELAY;
			} else if (strcmp(argv[i] + 8, "sync") == 0) {
				zio.fflags |= O_SYNC;
			} else if (strcmp(argv[i] + 8, "trunc") == 0) {
				zio.fflags |= O_TRUNC;
			} else {
				fprintf(stderr, "Invalid file open flag\n");
				return 1;
			}
		} else if (strncmp(argv[i], "--ioflag=", 9) == 0) {
			if (strcmp(argv[i] + 9, "append") == 0) {
				zio.ioflags |= RWF_APPEND;
			} else if (strcmp(argv[i] + 9, "nowait") == 0) {
				zio.ioflags |= RWF_NOWAIT;
			} else if (strcmp(argv[i] + 9, "hipri") == 0) {
				zio.ioflags |= RWF_HIPRI;
			} else {
				fprintf(stderr, "Invalid IO flag\n");
				return 1;
			}
		} else if (argv[i][0] == '-') {
			fprintf(stderr, "Invalid option \"%s\"\n", argv[i]);
			return 1;
		}
	}

	ret = zio_init(&zio, argv[argc - 1]);
	if (ret != 0)
		return 1;

	start = zio_usec();

	if (zio.async)
		ret = zio_run_async(&zio);
	else
		ret = zio_run_sync(&zio);
	if (ret != 0)
		ret = 1;

	if (ret == 0) {
		unsigned long long elapsed = zio_usec() - start;
		unsigned long long bw, iops;

		iops = zio.nr_ios * 1000000ULL / elapsed;
		bw = zio.nr_ios * zio.iosize * 1000000ULL / elapsed;

		printf("%u IOs done in %llu ms (%llu us)\n",
		       zio.nr_ios, elapsed / 1000, elapsed);
		printf("    %llu IOPS, %llu.%03llu MB/s\n",
		       iops, bw / 1000000, (bw % 1000000) / 1000);
	}

	zio_cleanup(&zio);

	return ret;
}
