/// Application that generates a continuous flow of data
/// cache misses.
///
/// USAGE: Usage (argument optional):
/// `cachekiller [num_iterations]`
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

    cache_body(array, ARRAY_SIZE, DCACHE_MAX_LINESIZE, num_iterations,
               miss_rate);

    return 0;
}
