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

#define NOBENCH()						\
	do {								\
		printf("      ");				\
		fflush(stdout);					\
	} while(0)

#define DECLARE_AND_BENCH(x)			\
	do {								\
		void x(tsc_count_t*);			\
		bench(x);						\
	} while(0)

#define BENCH0(x)						\
	do {								\
		printf("%-24s", #x);			\
		fflush(stdout);					\
		DECLARE_AND_BENCH(x ## _tp);	\
		printf("\n");					\
	} while(0)

#define BENCH_D1(x)						\
	do {								\
		printf("%-24s", #x);			\
		fflush(stdout);					\
		DECLARE_AND_BENCH(x ## _tp);	\
		DECLARE_AND_BENCH(x ## _lt1);	\
		printf("\n");					\
	} while(0)

#define BENCH_D2(x)						\
	do {								\
		printf("%-24s", #x);			\
		fflush(stdout);					\
		DECLARE_AND_BENCH(x ## _tp);	\
		DECLARE_AND_BENCH(x ## _lt1);	\
		DECLARE_AND_BENCH(x ## _lt2);	\
		printf("\n");					\
	} while(0)

#define BENCH_D3(x)						\
	do {								\
		printf("%-24s", #x);			\
		fflush(stdout);					\
		DECLARE_AND_BENCH(x ## _tp);	\
		DECLARE_AND_BENCH(x ## _lt1);	\
		DECLARE_AND_BENCH(x ## _lt2);	\
		DECLARE_AND_BENCH(x ## _lt3);	\
		printf("\n");					\
	} while(0)

#define BENCH_N2(x)						\
	do {								\
		printf("%-24s", #x);			\
		fflush(stdout);					\
		DECLARE_AND_BENCH(x ## _tp);	\
		NOBENCH();						\
		DECLARE_AND_BENCH(x ## _lt2);	\
		printf("\n");					\
	} while(0)

#define BENCH_N3(x)						\
	do {								\
		printf("%-24s", #x);			\
		fflush(stdout);					\
		DECLARE_AND_BENCH(x ## _tp);	\
		NOBENCH();						\
		DECLARE_AND_BENCH(x ## _lt2);	\
		DECLARE_AND_BENCH(x ## _lt3);	\
		printf("\n");					\
	} while(0)

#define BENCH_N4(x)						\
	do {								\
		printf("%-24s", #x);			\
		fflush(stdout);					\
		DECLARE_AND_BENCH(x ## _tp);	\
		NOBENCH();						\
		DECLARE_AND_BENCH(x ## _lt2);	\
		DECLARE_AND_BENCH(x ## _lt3);	\
		DECLARE_AND_BENCH(x ## _lt4);	\
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

	printf("instruction                 tp   lt1   lt2   lt3   lt4\n");
	printf("------------------------------------------------------\n");
	BENCH_D2(add_r64);
	BENCH_N2(vmovdqu8_xmm);
	BENCH_N2(vmovdqu8_ymm);
	BENCH_N2(vmovdqu8_zmm);
	BENCH_N2(vmovdqu16_xmm);
	BENCH_N2(vmovdqu16_ymm);
	BENCH_N2(vmovdqu16_zmm);
	BENCH_N2(vmovdqu32_xmm);
	BENCH_N2(vmovdqu32_ymm);
	BENCH_N2(vmovdqu32_zmm);
	BENCH_N2(vmovdqu64_xmm);
	BENCH_N2(vmovdqu64_ymm);
	BENCH_N2(vmovdqu64_zmm);
	BENCH_D2(vmovdqu8_mask_xmm);
	BENCH_D2(vmovdqu8_mask_ymm);
	BENCH_D2(vmovdqu8_mask_zmm);
	BENCH_D2(vmovdqu16_mask_xmm);
	BENCH_D2(vmovdqu16_mask_ymm);
	BENCH_D2(vmovdqu16_mask_zmm);
	BENCH_D2(vmovdqu32_mask_xmm);
	BENCH_D2(vmovdqu32_mask_ymm);
	BENCH_D2(vmovdqu32_mask_zmm);
	BENCH_D2(vmovdqu64_mask_xmm);
	BENCH_D2(vmovdqu64_mask_ymm);
	BENCH_D2(vmovdqu64_mask_zmm);
	BENCH_N2(vmovdqu8_maskz_xmm);
	BENCH_N2(vmovdqu8_maskz_ymm);
	BENCH_N2(vmovdqu8_maskz_zmm);
	BENCH_N2(vmovdqu16_maskz_xmm);
	BENCH_N2(vmovdqu16_maskz_ymm);
	BENCH_N2(vmovdqu16_maskz_zmm);
	BENCH_N2(vmovdqu32_maskz_xmm);
	BENCH_N2(vmovdqu32_maskz_ymm);
	BENCH_N2(vmovdqu32_maskz_zmm);
	BENCH_N2(vmovdqu64_maskz_xmm);
	BENCH_N2(vmovdqu64_maskz_ymm);
	BENCH_N2(vmovdqu64_maskz_zmm);
	BENCH_D2(paddb_xmm);
	BENCH_N3(vpaddb_xmm);
	BENCH_N3(vpaddb_zmm);
	BENCH_N3(vpaddq_xmm);
	BENCH_N3(vpaddq_zmm);
	BENCH_D3(vpaddb_mask_xmm);
	BENCH_D3(vpaddb_mask_zmm);
	BENCH_D3(vpaddq_mask_xmm);
	BENCH_D3(vpaddq_mask_zmm);
	BENCH_N3(vpaddb_maskz_xmm);
	BENCH_N3(vpaddb_maskz_zmm);
	BENCH_N3(vpaddq_maskz_xmm);
	BENCH_N3(vpaddq_maskz_zmm);
	BENCH_N2(pmovzxbw_xmm);
	BENCH_N2(vpmovzxbw_ymm);
	BENCH_N4(vpblendvb_xmm);
	BENCH_N3(vpblendmb_xmm);
	BENCH_N3(vpblendmb_zmm);
	BENCH_N3(vpblendmq_xmm);
	BENCH_N3(vpblendmq_zmm);
	BENCH_N3(vpblendmb_mask_xmm);
	BENCH_N3(vpblendmb_mask_zmm);
	BENCH_N3(vpblendmq_mask_xmm);
	BENCH_N3(vpblendmq_mask_zmm);
	BENCH_N3(vpblendmb_maskz_xmm);
	BENCH_N3(vpblendmb_maskz_zmm);
	BENCH_N3(vpblendmq_maskz_xmm);
	BENCH_N3(vpblendmq_maskz_zmm);
	BENCH_N2(pext_all0);
	BENCH_N2(pext_all1);
	BENCH_N2(pext_half);
	BENCH_N2(pext_lo);
	BENCH_N2(pext_hi);
	BENCH_N3(vpermb_xmm);
	BENCH_N3(vpermb_zmm);
	BENCH_N3(vpermw_zmm);
	BENCH_N3(vpermd_zmm);
	BENCH_N3(vpermq_zmm);
	BENCH_D3(vpermt2b_xmm);
	BENCH_D3(vpermt2b_zmm);
	BENCH_D3(vpermt2w_zmm);
	BENCH_D3(vpermt2d_zmm);
	BENCH_D3(vpermt2q_zmm);
	BENCH_D3(vpermi2b_zmm);
	BENCH_D3(vpermi2w_zmm);
	BENCH_D3(vpermi2d_zmm);
	BENCH_D3(vpermi2q_zmm);
	BENCH_N2(vpcompressb_xmm_all0);
	BENCH_N2(vpcompressb_zmm_all0);
	BENCH_N2(vpcompressb_xmm_all1);
	BENCH_N2(vpcompressb_zmm_all1);
	BENCH_N2(vpcompressb_xmm_half);
	BENCH_N2(vpcompressb_zmm_half);
	BENCH_N2(vpcompressw_zmm_half);
	BENCH_N2(vpcompressd_zmm_half);
	BENCH_N2(vpcompressq_zmm_half);
	BENCH_D3(vpgatherdd_zmm_k0);
	BENCH_D3(vpgatherqq_zmm_k0);
	BENCH_D3(vpgatherqq_ymm_k0);
	BENCH_D3(vpgatherqq_xmm_k0);
	BENCH_D3(vpgatherdd_zmm_all1);
	BENCH_D3(vpgatherqq_zmm_all1);
	BENCH0(vpscatterdd_zmm_all0);
	BENCH0(vpscatterqq_zmm_all0);
	BENCH0(vpscatterdd_zmm_all1);
	BENCH0(vpscatterqq_zmm_all1);
	BENCH_D3(vpdpwssd_xmm);
	BENCH_D3(vpdpwssd_ymm);
	BENCH_D3(vpdpwssd_zmm);
	BENCH_N3(vpmaddwd_xmm);
	BENCH_N3(vpmaddwd_ymm);
	BENCH_N3(vpmaddwd_zmm);
	BENCH_N3(vpmultishiftqb_xmm);
	BENCH_N3(vpmultishiftqb_ymm);
	BENCH_N3(vpmultishiftqb_zmm);
	BENCH_D3(vpternlogq_xmm);
	BENCH_D3(vpternlogq_ymm);
	BENCH_D3(vpternlogq_zmm);
	BENCH_N2(vpsllq_xmm_imm);
	BENCH_N2(vpsllq_ymm_imm);
	BENCH_N2(vpsllq_zmm_imm);
	BENCH_N3(vpsllq_xmm_xmm);
	BENCH_N3(vpsllq_ymm_xmm);
	BENCH_N3(vpsllq_zmm_xmm);
	BENCH_N3(vpsllvq_xmm);
	BENCH_N3(vpsllvq_ymm);
	BENCH_N3(vpsllvq_zmm);
	BENCH_N3(vpackuswb_xmm);
	BENCH_N3(vpackuswb_ymm);
	BENCH_N3(vpackuswb_zmm);
	BENCH_N3(vpunpcklbw_xmm);
	BENCH_N3(vpunpcklbw_ymm);
	BENCH_N3(vpunpcklbw_zmm);
	BENCH_N3(vpunpcklqdq_xmm);
	BENCH_N3(vpunpcklqdq_ymm);
	BENCH_N3(vpunpcklqdq_zmm);
	BENCH_N3(vpshufb_xmm);
	BENCH_N3(vpshufb_ymm);
	BENCH_N3(vpshufb_zmm);

	return 0;
}
