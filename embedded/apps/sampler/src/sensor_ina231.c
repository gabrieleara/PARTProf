#include <fcntl.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/ioctl.h>
#include <sys/sysinfo.h>

#include "private/ina231_private.h"
#include "readfile.h"
#include "sensor_ina231.h"

#define __SENSOR_INA231_BASE_INITIALIZER                                       \
    {                                                                          \
        {}, -1, "", sensor_ina231_read, sensor_ina231_close,                   \
            sensor_ina231_print_last,                                          \
    }

#define __SENSOR_INA231_INITIALIZER                                            \
    {                                                                          \
        __SENSOR_INA231_BASE_INITIALIZER, -1, {}                               \
    }

const struct sensor_ina231 SENSOR_INA231_INITIALIZER =
    __SENSOR_INA231_INITIALIZER;

// =========================================================
// SINGLE SENSOR
// =========================================================

// ------------------ Private Methods ------------------- //

static inline int sensor_ina231_enable_read(struct sensor_ina231 *sensor) {
    if (sensor->fd < 0)
        return 0;
    return ioctl(sensor->fd, INA231_IOCGSTATUS, &sensor->data);
}

static inline int sensor_ina231_enable_write(struct sensor_ina231 *self,
                                             unsigned char enable) {
    if (self->fd < 0)
        return 0;
    self->data.enable = enable ? 1 : 0;
    return ioctl(self->fd, INA231_IOCSSTATUS, &self->data);
}

// ------------------- Public Methods ------------------- //

struct sensor_ina231 *sensor_ina231_new() {
    struct sensor_ina231 *ptr = malloc(sizeof(struct sensor_ina231));
    if (ptr != NULL)
        *ptr = SENSOR_INA231_INITIALIZER;
    return ptr;
}

// Read the minimum update period among the various devices;
// typically all INA231 devices have the same update period
// Success if return >= 0
long sensor_ina231_update_period(struct sensor_ina231 *self, const char *node) {
    char value[32]; // Overallocated

    int nread = readfile(node, value, sizeof(value) - 1);
    if (nread < 1)
        goto error;

    value[nread] = '\0';

    // Parse number and unit, separated by a space character
    char *saveptr;
    char *number = strtok_r(value, " \0", &saveptr);
    char *unit = strtok_r(NULL, " \0", &saveptr);

    if (number[0] == '\0' || unit[0] == '\0')
        goto error;

    long period_us = atol(number);

    // Parse the unit
    if (strcmp(unit, "usec")) {
        // Do nothing, we like useconds
        goto success;
    } else {
        // TODO: implement something
        goto error;
    }

error:
    period_us = -1;

success:
    self->base.period_us = period_us;
    return period_us;
}

// Open a connection with the INA231 driver
// Success if return >= 0
int sensor_ina231_open(struct sensor_ina231 *self, const char *fname,
                       const char *update_period_fname) {
    int res;

    res = open(fname, O_RDWR);
    if (res < 0)
        goto error;

    self->fd = res;

    // Read sensor enable status
    if ((res = sensor_ina231_enable_read(self) < 0))
        goto error;

    // If not enabled, enable
    if (self->data.enable == SENSOR_DISABLED &&
        (res = sensor_ina231_enable_write(self, SENSOR_ENABLED)) < 0)
        goto error;

    if ((res = sensor_ina231_update_period(self, update_period_fname)) < 0)
        goto error;

    if ((res = sensor_ina231_read((struct sensor *)self)) < 0)
        goto error;

    const size_t last = sizeof(self->base.name) - 1;
    strncpy(self->base.name, self->data.name, last);
    self->base.name[last] = '\0';

    goto success;

error:
    sensor_ina231_close((struct sensor *)self);
    self->fd = res;

success:
    return self->fd;
}

// Close a connection with the INA231 driver
void sensor_ina231_close(struct sensor *sself) {
    struct sensor_ina231 *self = (struct sensor_ina231 *)sself;
    if (self->fd >= 0)
        close(self->fd);
}

// Read data from the INA231 driver
// Success if return >= 0
int sensor_ina231_read(struct sensor *sself) {
    struct sensor_ina231 *self = (struct sensor_ina231 *)sself;
    if (self->fd < 0)
        return -1;
    return ioctl(self->fd, INA231_IOCGREG, &self->data);
}

void sensor_ina231_print_last(struct sensor *sself) {
    struct sensor_ina231 *self = (struct sensor_ina231 *)sself;
    printf("%s_uA %u\n", self->base.name, self->data.cur_uA);
    printf("%s_uV %u\n", self->base.name, self->data.cur_uV);
    printf("%s_uW %u\n", self->base.name, self->data.cur_uW);
}

// =========================================================
// MULTIPLE SENSORS DETECTION AND INITIALIZATION
// =========================================================

struct list_head *sensors_ina231_init() {
    struct list_head *list = list_new();
    if (list == NULL)
        exit(EXIT_FAILURE);

    struct sensor_ina231 *s = NULL;

    for (int i = 0; i < INA231_SENSOR_MAX; ++i) {
        if (s == NULL) {
            s = sensor_ina231_new();
            if (s == NULL)
                exit(EXIT_FAILURE);
        }

        int res = sensor_ina231_open(s, DEV_SENSORS[i], DEV_UPDATE_PERIODS[i]);

        if (res >= 0) {
            // Success! Add it to the list!
            list_add_tail(&s->base.list, list);
            s = NULL;
        } else {
            // Failure! Keep going! Avoid re-allocation!
        }
    }

    if (s != NULL)
        free(s);

    return list;
}
