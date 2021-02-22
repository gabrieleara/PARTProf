#ifndef SENSOR_IIO_PRIVATE_H
#define SENSOR_IIO_PRIVATE_H

#define DEV_NAME_IIO_TEMP "cpu_iio_temp"
#define DEV_PATH_IIO_TEMP_OFFSET                                               \
    "/sys/bus/iio/devices/iio:device0/in_temp0_ps_temp_offset"
#define DEV_PATH_IIO_TEMP_SCALE                                                \
    "/sys/bus/iio/devices/iio:device0/in_temp0_ps_temp_scale"
#define DEV_PATH_IIO_TEMP_RAW                                                  \
    "/sys/bus/iio/devices/iio:device0/in_temp0_ps_temp_raw"

#endif // SENSOR_IIO_PRIVATE_H
