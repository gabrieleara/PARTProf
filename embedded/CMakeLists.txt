cmake_minimum_required(VERSION 3.12.0)

project(PARTProf_EMBEDDED
    VERSION 0.1.0
    LANGUAGES C
)

# Set a default build type if none was specified
set(default_build_type "Release")

add_subdirectory(apps/sampler)
add_subdirectory(apps/cacheapp)
add_subdirectory(apps/forever)
