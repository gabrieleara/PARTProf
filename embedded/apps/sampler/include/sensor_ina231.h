#ifndef SENSOR_INA231_H
#define SENSOR_INA231_H

#include "sensor.h"

// Structrure used to read and store data from sensors using IOCTL
struct ina231_iocreg_t {
    char name[20];
    unsigned int enable;
    unsigned int cur_uV;
    unsigned int cur_uA;
    unsigned int cur_uW;
};

struct sensor_ina231 {
    struct sensor base;
    int fd;
    struct ina231_iocreg_t data;
};

// ---------------------- METHODS ----------------------- //

// Close a connection with the INA231 driver
extern void sensor_ina231_close(struct sensor *sself);

// Read data from the INA231 driver
extern int sensor_ina231_read(struct sensor *sself);

// Print last data sample collected
extern void sensor_ina231_print_last(struct sensor *sself);

// ============ DETECTION AND INITIALIZATION ============ //

extern struct list_head *sensors_ina231_init();

#endif // SENSOR_INA231_H
