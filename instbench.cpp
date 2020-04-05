#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>

#include <linux/perf_event.h>
#include <linux/hw_breakpoint.h>
#include <sys/syscall.h>

#include "instbench.h"

void bench(benchfn_t fn)
{
	tsc_count_t tc;

	sleep(1);
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
		printf("%-16s", #x);			\
		fflush(stdout);					\
		DECLARE_AND_BENCH(x ## _tp);	\
		DECLARE_AND_BENCH(x ## _lt1);	\
		printf("\n");					\
	} while(0)

#define BENCH2(x)						\
	do {								\
		printf("%-16s", #x);			\
		fflush(stdout);					\
		DECLARE_AND_BENCH(x ## _tp);	\
		DECLARE_AND_BENCH(x ## _lt1);	\
		DECLARE_AND_BENCH(x ## _lt2);	\
		printf("\n");					\
	} while(0)

#define BENCH3(x)						\
	do {								\
		printf("%-16s", #x);			\
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

	printf("instruction         tp   lt1   lt2\n");
	printf("----------------------------------\n");
	BENCH2(add_r64);
	BENCH2(paddb_xmm);
	BENCH2(vpaddb_xmm);
	BENCH1(pmovzxbw_xmm);
	BENCH1(vpmovzxbw_ymm);
	BENCH1(pext_all0);
	BENCH1(pext_all1);
	BENCH1(pext_half);
	BENCH1(pext_lo);
	BENCH1(pext_hi);

	return 0;
}
