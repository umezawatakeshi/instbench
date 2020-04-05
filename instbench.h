#pragma once

#ifdef _WIN32

#include <windows.h>
static inline void sleep(unsigned int seconds)
{
	Sleep(seconds * 1000);
}

#elif defined(__unix__)

#include <unistd.h>

#endif


struct tsc_count_t
{
	uint64_t tsc;
	uint32_t count;
};

typedef void (*benchfn_t)(tsc_count_t*);
