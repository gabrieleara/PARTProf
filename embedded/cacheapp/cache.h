/// Provides a function that generates a fixed rate of data
/// cache misses.
///
/// NOTICE: the miss_rate will be approximated using integer
/// fractions of the cache line size.
///
/// Rationale behind the implementation: Suppose the
/// required rate of cache misses is miss_rate every 100
/// (roughly) and that the dimendion of the data cache line
/// size is line_size. Then, displacement between
/// consecutive accesses to the data array should be:
/// ` increment = line_size * miss_rate / 100 `
///
/// EXAMPLES:
/// miss_rate = 0    ==> increment = 0
/// miss_rate = 25   ==> increment = line_size / 4
/// miss_rate = 50   ==> increment = line_size / 2
/// miss_rate = 75   ==> increment = line_size * 3 / 4
/// miss_rate = 100  ==> increment = line_size

#ifndef CACHE_H
#define CACHE_H

#include <stdint.h>
#include <stdlib.h>

static inline void cache_body(register uint8_t array[],
                              register const size_t array_size,
                              register const size_t line_size,
                              register const size_t num_iterations,
                              const size_t miss_rate) {
    register const size_t increment = (line_size * miss_rate) / 100;
    register size_t index = 0;
    for (register size_t i = 0; i < num_iterations; ++i) {
        array[index] = 0;
        index += increment;
        if (index >= array_size) {
            index -= array_size;
        }
    }
}

#endif // CACHE_H
