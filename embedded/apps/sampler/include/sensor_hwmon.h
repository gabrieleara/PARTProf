#ifndef SENSOR_HWMON_H
#define SENSOR_HWMON_H

#include "sensor.h"

struct hwmon_measure {
    char in_path[64];
    char out_path[64];
    long in_value;
    long out_value;
    long diff_value;
};

struct hwmon_data {
    char name[32];
    struct hwmon_measure current;
    struct hwmon_measure voltage;
    struct hwmon_measure power;
    struct hwmon_measure temp;
};

struct sensor_hwmon {
    struct sensor base;
    struct hwmon_data data;
};

// ---------------------- METHODS ----------------------- //

// Close a connection with the HWMON driver
extern void sensor_hwmon_close(struct sensor *sself);

// Read data from the HWMON driver
extern int sensor_hwmon_read(struct sensor *sself);

// Print last data sample collected
extern void sensor_hwmon_print_last(struct sensor *sself);

// ============ DETECTION AND INITIALIZATION ============ //

extern struct list_head *sensors_hwmon_init();

#endif // SENSOR_HWMON_H
