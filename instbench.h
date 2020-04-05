#pragma once

#include <unistd.h>

extern int perf_fd;

static inline void read_cycle_counter(uint64_t& val)
{
	read(perf_fd, &val, sizeof(val));
}

static inline uint64_t read_cycle_counter()
{
	uint64_t val;
	read_cycle_counter(val);
	return val;
}

struct tsc_count_t
{
	uint64_t tsc;
	uint32_t count;
};

typedef void (*benchfn_t)(tsc_count_t*);
