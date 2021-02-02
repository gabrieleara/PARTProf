#include <fcntl.h>
#include <limits.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/sysinfo.h>

#include "private/iio_private.h"
#include "readfile.h"
#include "sensor_iio.h"

// =========================================================
// SINGLE SENSOR
// =========================================================

#define __SENSOR_IIO_BASE_INITIALIZER                                          \
    { {}, -1, "", sensor_iio_read, sensor_iio_close, sensor_iio_print_last, }

#define __SENSOR_IIO_INITIALIZER                                               \
    { __SENSOR_IIO_BASE_INITIALIZER, "", "", "", 0, 0, 0, 0, }

const struct sensor_iio SENSOR_IIO_INITIALIZER = __SENSOR_IIO_INITIALIZER;

// ------------------ Private Methods ------------------- //

struct sensor_iio *sensor_iio_new() {
    struct sensor_iio *ptr = malloc(sizeof(struct sensor_iio));
    if (ptr != NULL)
        *ptr = SENSOR_IIO_INITIALIZER;
    return ptr;
}

// Check that the given file exists
// Success if return >= 0
int sensor_iio_open_single(char *dest, const char *fpath, size_t dest_size) {
    strncpy(dest, fpath, dest_size - 1);
    dest[dest_size - 1] = '\0';

    if (access(dest, F_OK) != 0)
        return -1;

    return 0;
}

int sensor_iio_open(struct sensor_iio *self, const char *name,
                    const char *fpath_offset, const char *fpath_scale,
                    const char *fpath_raw) {
    strncpy(self->base.name, name, sizeof(self->base.name) - 1);
    self->base.name[sizeof(self->base.name) - 1] = '\0';

    int res;

    res = sensor_iio_open_single(self->fpath_raw, fpath_raw,
                                 sizeof(self->fpath_raw));
    if (res < 0)
        return res;

    res = sensor_iio_open_single(self->fpath_scale, fpath_scale,
                                 sizeof(self->fpath_raw));
    if (res < 0)
        return res;

    res = sensor_iio_open_single(self->fpath_offset, fpath_offset,
                                 sizeof(self->fpath_raw));
    return res;
}

// ------------------- Public Methods ------------------- //

// Close a connection with the file driver
void sensor_iio_close(struct sensor *sself __attribute((unused))) {}

// Read data from the file driver
// Success if return >= 0
int sensor_iio_read(struct sensor *sself) {
    struct sensor_iio *self = (struct sensor_iio *)sself;

    self->offset = readdouble(self->fpath_offset);
    self->scale = readdouble(self->fpath_scale);
    self->raw = readdouble(self->fpath_raw);

    self->value = self->scale * (self->raw + self->offset) / 1000.0;

    return 0;
}

void sensor_iio_print_last(struct sensor *sself) {
    struct sensor_iio *self = (struct sensor_iio *)sself;
    printf("%s %f\n", self->base.name, self->value);
}

// =========================================================
// MULTIPLE SENSORS DETECTION AND INITIALIZATION
// =========================================================

struct list_head *sensors_iio_init() {
    struct list_head *list = list_new();
    if (list == NULL)
        exit(EXIT_FAILURE);

    struct sensor_iio *s = sensor_iio_new();
    if (s == NULL)
        exit(EXIT_FAILURE);

    int res = sensor_iio_open(s, DEV_NAME_IIO_TEMP, DEV_PATH_IIO_TEMP_OFFSET,
                              DEV_PATH_IIO_TEMP_SCALE, DEV_PATH_IIO_TEMP_RAW);
    if (res < 0)
        free(s);
    else
        list_add_tail(&s->base.list, list);

    return list;
}
