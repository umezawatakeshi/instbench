#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <time.h>

#include <linux/perf_event.h>
#include <linux/hw_breakpoint.h>
#include <sys/syscall.h>

#include "instbench.h"

void* tmpbuf = aligned_alloc(1024*1024, 4096);

timespec ts_100ms = { 0, 100*1000*1000 };

void bench(benchfn_t fn)
{
	tsc_count_t tc;

	nanosleep(&ts_100ms, NULL);
	fn(&tc);
	fn(&tc);

	printf(" %5.2f", ((double)tc.tsc) / ((double)tc.count));
	fflush(stdout);
}

#define DECLARE_AND_BENCH(x)			\
	do {								\
		void x(tsc_count_t*);			\
		bench(x);						\
	} while(0)

#define BENCH1(x)						\
	do {								\
		printf("%-24s", #x);			\
		fflush(stdout);					\
		DECLARE_AND_BENCH(x ## _tp);	\
		DECLARE_AND_BENCH(x ## _lt1);	\
		printf("\n");					\
	} while(0)

#define BENCH0(x)						\
	do {								\
		printf("%-24s", #x);			\
		fflush(stdout);					\
		DECLARE_AND_BENCH(x ## _tp);	\
		printf("\n");					\
	} while(0)

#define BENCH2(x)						\
	do {								\
		printf("%-24s", #x);			\
		fflush(stdout);					\
		DECLARE_AND_BENCH(x ## _tp);	\
		DECLARE_AND_BENCH(x ## _lt1);	\
		DECLARE_AND_BENCH(x ## _lt2);	\
		printf("\n");					\
	} while(0)

#define BENCH3(x)						\
	do {								\
		printf("%-24s", #x);			\
		fflush(stdout);					\
		DECLARE_AND_BENCH(x ## _tp);	\
		DECLARE_AND_BENCH(x ## _lt1);	\
		DECLARE_AND_BENCH(x ## _lt2);	\
		DECLARE_AND_BENCH(x ## _lt3);	\
		printf("\n");					\
	} while(0)

int perf_fd = -1;

static int perf_event_open(struct perf_event_attr *hw_event, pid_t pid, int cpu, int group_fd, unsigned long flags)
{
	return (int)syscall(__NR_perf_event_open, hw_event, pid, cpu, group_fd, flags);
}

void init_cycle_counter()
{
	struct perf_event_attr attr;
	memset(&attr, 0, sizeof(attr));

	attr.type = PERF_TYPE_HARDWARE;
	attr.size = sizeof(attr);
	attr.config = PERF_COUNT_HW_CPU_CYCLES;
	attr.exclude_kernel = 1;

	perf_fd = perf_event_open(&attr, 0, -1, -1, 0);
	if (perf_fd == -1) {
		perror("perf_event_open");
		exit(1);
	}
}

int main(int argc, char **argv)
{
	init_cycle_counter();

	printf("instruction                 tp   lt1   lt2   lt3\n");
	printf("------------------------------------------------\n");
	BENCH2(add_r64);
	BENCH2(paddb_xmm);
	BENCH2(vpaddb_xmm);
	BENCH1(pmovzxbw_xmm);
	BENCH1(vpmovzxbw_ymm);
	BENCH3(vpblendvb_xmm);
	BENCH1(pext_all0);
	BENCH1(pext_all1);
	BENCH1(pext_half);
	BENCH1(pext_lo);
	BENCH1(pext_hi);
	BENCH2(vpermb_xmm);
	BENCH2(vpermb_zmm);
	BENCH2(vpermw_zmm);
	BENCH2(vpermd_zmm);
	BENCH2(vpermq_zmm);
	BENCH3(vpermt2b_xmm);
	BENCH3(vpermt2b_zmm);
	BENCH3(vpermt2w_zmm);
	BENCH3(vpermt2d_zmm);
	BENCH3(vpermt2q_zmm);
	BENCH3(vpermi2b_zmm);
	BENCH3(vpermi2w_zmm);
	BENCH3(vpermi2d_zmm);
	BENCH3(vpermi2q_zmm);
	BENCH1(vpcompressb_xmm_all0);
	BENCH1(vpcompressb_zmm_all0);
	BENCH1(vpcompressb_xmm_all1);
	BENCH1(vpcompressb_zmm_all1);
	BENCH1(vpcompressb_xmm_half);
	BENCH1(vpcompressb_zmm_half);
	BENCH1(vpcompressw_zmm_half);
	BENCH1(vpcompressd_zmm_half);
	BENCH1(vpcompressq_zmm_half);
	BENCH3(vpgatherdd_zmm_k0);
	BENCH3(vpgatherqq_zmm_k0);
	BENCH3(vpgatherqq_ymm_k0);
	BENCH3(vpgatherqq_xmm_k0);
	BENCH3(vpgatherdd_zmm_all1);
	BENCH3(vpgatherqq_zmm_all1);
	BENCH0(vpscatterdd_zmm_all0);
	BENCH0(vpscatterqq_zmm_all0);
	BENCH0(vpscatterdd_zmm_all1);
	BENCH0(vpscatterqq_zmm_all1);
	BENCH3(vpdpwssd_xmm);
	BENCH3(vpdpwssd_ymm);
	BENCH3(vpdpwssd_zmm);
	BENCH2(vpmaddwd_xmm);
	BENCH2(vpmaddwd_ymm);
	BENCH2(vpmaddwd_zmm);
	BENCH2(vpmultishiftqb_xmm);
	BENCH2(vpmultishiftqb_ymm);
	BENCH2(vpmultishiftqb_zmm);

	return 0;
}
