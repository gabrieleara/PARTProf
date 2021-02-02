#ifndef SENSOR_H
#define SENSOR_H

#include "list.h"

enum sample_type {
    NONE = 0,
};

#define METHOD(ret, name, ...) ret (*name)(__VA_ARGS__)

#define __SENSOR_INITIALIZER                                                   \
    { {}, -1, "", NULL, NULL, NULL }

// TODO: standard sensor name
struct sensor {
    struct list_head list;
    long period_us;
    char name[32];
    METHOD(int, read, struct sensor *self);
    METHOD(void, close, struct sensor *self);
    METHOD(void, print_last, struct sensor *self);
};

#endif // SENSOR_H
