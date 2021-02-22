# Flags
set(CMAKE_C_STANDARD 11)
set(CMAKE_C_FLAGS "-Wall -Wextra -Werror -O0") # Force non-optimized asm
set(CMAKE_C_FLAGS_DEBUG "-O0 -ggdb")
set(CMAKE_CPP_FLAGS_RELEASE "-DNDEBUG")

# Targets
add_executable(cachekiller  cachekiller.c)
add_executable(cachesaver   cachesaver.c)
add_executable(cachestress  cachestress.c)

# -------------------------------------------------------- #

# NOTE: on most boards the getconf command does not work to
# retrieve the size of the cache (and the length of cache
# lines); for this reason, it is advised to use exported
# variables to provide the two dimensions.

# execute_process(COMMAND getconf LEVEL1_DCACHE_SIZE
#     OUTPUT_VARIABLE DEFAULT_DCACHE_MAX_SIZE)
# execute_process(COMMAND getconf LEVEL1_DCACHE_LINESIZE
#     OUTPUT_VARIABLE DEFAULT_DCACHE_MAX_LINESIZE)

set(DEFAULT_DCACHE_MAX_SIZE     2097152)
set(DEFAULT_DCACHE_MAX_LINESIZE 64)

if(DEFINED ENV{DCACHE_MAX_SIZE})
    set(DCACHE_MAX_SIZE $ENV{DCACHE_MAX_SIZE})
else()
    set(DCACHE_MAX_SIZE ${DEFAULT_DCACHE_MAX_SIZE})
endif()

if(DEFINED ENV{DCACHE_MAX_LINESIZE})
    set(DCACHE_MAX_LINESIZE $ENV{DCACHE_MAX_LINESIZE})
else()
    set(DCACHE_MAX_LINESIZE ${DEFAULT_DCACHE_MAX_LINESIZE})
endif()

add_compile_definitions(DCACHE_MAX_SIZE=${DCACHE_MAX_SIZE})
add_compile_definitions(DCACHE_MAX_LINESIZE=${DCACHE_MAX_LINESIZE})

# -------------------------------------------------------- #
