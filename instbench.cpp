#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

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


int main(int argc, char **argv)
{
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
