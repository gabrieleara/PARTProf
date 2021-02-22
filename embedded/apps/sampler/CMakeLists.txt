# Flags
set(CMAKE_C_STANDARD 11)
set(CMAKE_C_FLAGS "-Wall -Wextra -Werror")
set(CMAKE_C_FLAGS_DEBUG "-O0 -ggdb")
set(CMAKE_CPP_FLAGS_RELEASE "-DNDEBUG")

# Targets
add_executable(sampler)

# Headers directory
target_include_directories(sampler PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/include
)

# Source files
target_sources(sampler PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/src/periodic.c
    ${CMAKE_CURRENT_SOURCE_DIR}/src/sample_sensors.c
    ${CMAKE_CURRENT_SOURCE_DIR}/src/sensor_file.c
    ${CMAKE_CURRENT_SOURCE_DIR}/src/sensor_hwmon.c
    ${CMAKE_CURRENT_SOURCE_DIR}/src/sensor_iio.c
    ${CMAKE_CURRENT_SOURCE_DIR}/src/sensor_ina226.c
    ${CMAKE_CURRENT_SOURCE_DIR}/src/sensor_ina231.c
    ${CMAKE_CURRENT_SOURCE_DIR}/src/time_utils.c
)

# The udev library is used by the SmartPower sensor.
# Since most boards may not need it and having it installed
# should not be mandatory, it is optional.
find_library(LIB_UDEV udev)
if(NOT LIB_UDEV)
    add_compile_definitions(UDEV_NOTFOUND)
else()
    target_sources(sampler PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/src/sensor_smartpower.c
        ${CMAKE_CURRENT_SOURCE_DIR}/src/hid.c
    )

    target_link_libraries(sampler PRIVATE
        udev
    )
endif()
