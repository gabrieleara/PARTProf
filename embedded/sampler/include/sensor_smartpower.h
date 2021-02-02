#ifndef SENSOR_SMARTPOWER_H
#define SENSOR_SMARTPOWER_H

#include "hidapi.h"
#include "sensor.h"
#include <stdint.h>

struct sensor_smartpower {
    struct sensor base;

    hid_device *device;

    double voltage;
    double current;
    double power;

    int is_started;
    int is_on;
};

// ---------------------- METHODS ----------------------- //

// Close a connection with the smartpower driver
extern void sensor_smartpower_close(struct sensor *sself);

// Read data from the smartpower driver
extern int sensor_smartpower_read(struct sensor *sself);

// Print last data sample collected
extern void sensor_smartpower_print_last(struct sensor *sself);

// ============ DETECTION AND INITIALIZATION ============ //

extern struct list_head *sensors_smartpower_init();
#endif // SENSOR_SMARTPOWER_H
