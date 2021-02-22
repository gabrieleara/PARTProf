# Flags
set(CMAKE_C_STANDARD 11)
set(CMAKE_C_FLAGS "-O2")
set(CMAKE_C_FLAGS_DEBUG "-O0 -ggdb")
set(CMAKE_CPP_FLAGS_RELEASE "-DNDEBUG")

# Targets
add_executable(forever  forever.c)
