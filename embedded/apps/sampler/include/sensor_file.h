#ifndef SENSOR_FILE_H
#define SENSOR_FILE_H

#include "sensor.h"

struct sensor_file {
    struct sensor base;
    char fpath[128]; // TODO: increase if necessary
    char data[20];
};

// ---------------------- METHODS ----------------------- //

// Close a connection with the file driver
extern void sensor_file_close(struct sensor *sself);

// Read data from the file driver
extern int sensor_file_read(struct sensor *sself);

// Print last data sample collected
extern void sensor_file_print_last(struct sensor *sself);

// ============ DETECTION AND INITIALIZATION ============ //

extern struct list_head *sensors_file_init();
#endif // SENSOR_FILE_H
