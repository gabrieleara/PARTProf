#ifndef SENSOR_IIO_H
#define SENSOR_IIO_H

#include "sensor.h"

struct sensor_iio {
    struct sensor base;
    char fpath_offset[128]; // TODO: increase if necessary
    char fpath_raw[128];    // TODO: increase if necessary
    char fpath_scale[128];  // TODO: increase if necessary
    double offset;
    double scale;
    double raw;
    double value;
};

// ---------------------- METHODS ----------------------- //

// Close a connection with the iio driver
extern void sensor_iio_close(struct sensor *sself);

// Read data from the iio driver
extern int sensor_iio_read(struct sensor *sself);

// Print last data sample collected
extern void sensor_iio_print_last(struct sensor *sself);

// ============ DETECTION AND INITIALIZATION ============ //

extern struct list_head *sensors_iio_init();
#endif // SENSOR_IIO_H
