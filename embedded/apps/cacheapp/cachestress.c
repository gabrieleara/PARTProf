/// Application that generates a fixed rate of data cache
/// misses.
///
/// USAGE: Usage (both arguments optional):
/// `cachestress [num_iterations] [miss_rate]`
///
/// NOTICE: the miss_rate will be approximated using integer
/// fractions of the cache line size.
///
/// NOTICE: This application assumes the following two
/// macros defined through compiler flags:
/// - DCACHE_MAX_SIZE
/// - DCACHE_MAX_LINESIZE

#include "cache.h"

#define ARRAY_SIZE (DCACHE_MAX_SIZE << 3)

uint8_t array[ARRAY_SIZE] __attribute__((aligned(DCACHE_MAX_LINESIZE)));

int main(int argc, char *argv[]) {
    long num_iterations = 1000000000L;
    long miss_rate = 100;

    if (argc > 1)
        num_iterations = atol(argv[1]);

    if (argc > 2) {
        miss_rate = atol(argv[2]);
        miss_rate = (miss_rate > 100) ? 100 : miss_rate;
        miss_rate = (miss_rate < 0) ? 0 : miss_rate;
    }

    cache_body(array, ARRAY_SIZE, DCACHE_MAX_LINESIZE, num_iterations,
               miss_rate);

    return 0;
}
