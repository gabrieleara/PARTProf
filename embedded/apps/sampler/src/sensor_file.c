#include <fcntl.h>
#include <limits.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/sysinfo.h>

#include "private/file_private.h"
#include "readfile.h"
#include "sensor_file.h"

// =========================================================
// SINGLE SENSOR
// =========================================================

#define __SENSOR_FILE_BASE_INITIALIZER                                         \
    { {}, -1, "", sensor_file_read, sensor_file_close, sensor_file_print_last, }

#define __SENSOR_FILE_INITIALIZER                                              \
    {                                                                          \
        __SENSOR_FILE_BASE_INITIALIZER, {}, {}                                 \
    }

const struct sensor_file SENSOR_FILE_INITIALIZER = __SENSOR_FILE_INITIALIZER;

// ------------------ Private Methods ------------------- //

struct sensor_file *sensor_file_new() {
    struct sensor_file *ptr = malloc(sizeof(struct sensor_file));
    if (ptr != NULL)
        *ptr = SENSOR_FILE_INITIALIZER;
    return ptr;
}

// Check that the given file exists
// Success if return >= 0
int sensor_file_open(struct sensor_file *self, const char *name,
                     const char *fpath) {
    strncpy(self->base.name, name, sizeof(self->base.name) - 1);
    self->base.name[sizeof(self->base.name) - 1] = '\0';

    strncpy(self->fpath, fpath, sizeof(self->fpath) - 1);
    self->fpath[sizeof(self->fpath) - 1] = '\0';

    return sensor_file_read((struct sensor *)self);
}

// ------------------- Public Methods ------------------- //

// Close a connection with the file driver
void sensor_file_close(struct sensor *sself __attribute((unused))) {}

// Read data from the file driver
// Success if return >= 0
int sensor_file_read(struct sensor *sself) {
    struct sensor_file *self = (struct sensor_file *)sself;
    int res = readfile(self->fpath, self->data, sizeof(self->data) - 1);
    // Force null termination on success
    if (res >= 0) {
        self->data[res] = '\0';
        if (res > 0 && self->data[res - 1] == '\n') {
            self->data[res - 1] = '\0';
        }
    }

    return res;
}

void sensor_file_print_last(struct sensor *sself) {
    struct sensor_file *self = (struct sensor_file *)sself;
    printf("%s %s\n", self->base.name, self->data);
}

// =========================================================
// MULTIPLE SENSORS DETECTION AND INITIALIZATION
// =========================================================

struct list_head *sensors_file_multi_init(int howmany, const char *name_prefix,
                                          const char *fpath_prefix,
                                          const char *fpath_suffix) {
    struct list_head *list = list_new();
    if (list == NULL)
        exit(EXIT_FAILURE);

    struct sensor_file *s = NULL;
    int res;

    char name[32];
    char fpath[64];

    strcpy(name, name_prefix);
    strcpy(fpath, fpath_prefix);

    const size_t name_pointer = strlen(name);
    const size_t fpath_pointer = strlen(fpath);

    size_t suffix_pointer;
    bool iterate_until_error = false;

    if (howmany == -1) {
        iterate_until_error = true;
        howmany = INT_MAX;
    }

    for (int i = 0; i < howmany; ++i) {
        if (s == NULL) {
            s = sensor_file_new();
            if (s == NULL)
                exit(EXIT_FAILURE);
        }

        sprintf(name + name_pointer, "%d", i);

        suffix_pointer = sprintf(fpath + fpath_pointer, "%d", i);
        strcpy(fpath + fpath_pointer + suffix_pointer, fpath_suffix);

        res = sensor_file_open(s, name, fpath);
        if (res >= 0) {
            // Success! Add it to the list!
            list_add_tail(&s->base.list, list);
            s = NULL;
        } else {
            // Failure! Keep going (if that's what you want)!
            // Avoiding re-allocation by not freeing and re-allocating current
            // structure.
            if (iterate_until_error)
                break;
        }
    }

    if (s != NULL)
        free(s);

    return list;
}

struct list_head *sensors_file_cpufreq_init() {
    return sensors_file_multi_init(get_nprocs_conf(), DEV_NAME_CPUFREQ,
                                   DEV_PATH_CPUFREQ_BASE, DEV_PATH_CPUFREQ_END);
}

struct list_head *sensors_file_thermal_init() {
    return sensors_file_multi_init(-1, DEV_NAME_THERMAL, DEV_PATH_THERMAL_BASE,
                                   DEV_PATH_THERMAL_END);
}

struct list_head *sensors_file_init() {
    struct list_head *list = list_new();
    if (list == NULL)
        exit(EXIT_FAILURE);

    struct list_head *tail;

    tail = sensors_file_cpufreq_init();
    if (!list_empty(tail)) {
        list_splice_tail(tail, list);
    }
    free(tail);

    tail = sensors_file_thermal_init();
    if (!list_empty(tail)) {
        list_splice_tail(tail, list);
    }
    free(tail);

    struct sensor_file *s = sensor_file_new();
    if (s == NULL)
        exit(EXIT_FAILURE);

    int res = sensor_file_open(s, DEV_NAME_CPUFAN, DEV_PATH_CPUFAN);
    if (res < 0)
        free(s);
    else
        list_add_tail(&s->base.list, list);

    return list;
}
