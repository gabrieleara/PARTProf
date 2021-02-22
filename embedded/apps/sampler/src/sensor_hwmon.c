#include <dirent.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "private/hwmon_private.h"
#include "readfile.h"
#include "sensor_hwmon.h"

#define __SENSOR_HWMON_DATA_INITIALIZER                                        \
    {}

#define __SENSOR_HWMON_BASE_INITIALIZER                                        \
    {                                                                          \
        {}, -1, "", sensor_hwmon_read, sensor_hwmon_close,                     \
            sensor_hwmon_print_last,                                           \
    }

#define __SENSOR_HWMON_INITIALIZER                                             \
    { __SENSOR_HWMON_BASE_INITIALIZER, __SENSOR_HWMON_DATA_INITIALIZER }

const struct sensor_hwmon SENSOR_HWMON_INITIALIZER = __SENSOR_HWMON_INITIALIZER;

// ------------------ Private Methods ------------------- //

static inline void set_file_if_exists(char *dest, const char *fname_base,
                                      const int fname_base_len,
                                      const char *fname_suffix) {
    strcpy(dest, fname_base);
    strcpy(dest + fname_base_len, fname_suffix);

    // If file does not exist, do not set the file name
    if (access(dest, F_OK) != 0) {
        dest[0] = '\0';
    }
}

struct sensor_hwmon *sensor_hwmon_new() {
    struct sensor_hwmon *ptr = malloc(sizeof(struct sensor_hwmon));
    if (ptr != NULL)
        *ptr = SENSOR_HWMON_INITIALIZER;
    return ptr;
}

// Success if return >= 0
long sensor_hwmon_update_period(struct sensor_hwmon *self __attribute((unused)),
                                const char *node __attribute((unused))) {
    // TODO:
    return 0;
}

static inline void sensor_hwmon_getlist(struct list_head *list) {
    DIR *dir;
    struct dirent *dirent;

    char buffer[100];
    char fname_buff[100] = HWMON_DIR;

    size_t name_len;

    dir = opendir(HWMON_DIR);

    while ((dirent = readdir(dir)) != NULL) {
        if (strcmp(".", dirent->d_name) == 0 ||
            strcmp("..", dirent->d_name) == 0) {
            continue;
        }

        name_len = strlen(dirent->d_name);

        strcpy(fname_buff + HWMON_BASE_IDX, dirent->d_name);
        strcpy(fname_buff + HWMON_BASE_IDX + name_len, HWMON_NAME);

        int res = readfile(fname_buff, buffer, sizeof(buffer) - 1);
        if (res < 1)
            continue;

        buffer[res] = '\0';
        if (buffer[res - 1] == '\n')
            buffer[res - 1] = '\0';

        // Get back original directory name
        fname_buff[HWMON_BASE_IDX + name_len] = '\0';

        struct sensor_hwmon *sensor = sensor_hwmon_new();

        // Copy current directory name
        strcpy(sensor->data.name, buffer);

        // Current
        set_file_if_exists(sensor->data.current.in_path, fname_buff,
                           HWMON_BASE_IDX + name_len, HWMON_CURR_IN);
        set_file_if_exists(sensor->data.current.out_path, fname_buff,
                           HWMON_BASE_IDX + name_len, HWMON_CURR_OUT);

        // Voltage
        set_file_if_exists(sensor->data.voltage.in_path, fname_buff,
                           HWMON_BASE_IDX + name_len, HWMON_VOLT_IN);
        set_file_if_exists(sensor->data.voltage.out_path, fname_buff,
                           HWMON_BASE_IDX + name_len, HWMON_VOLT_OUT);

        // Power
        set_file_if_exists(sensor->data.power.in_path, fname_buff,
                           HWMON_BASE_IDX + name_len, HWMON_POWER_IN);
        set_file_if_exists(sensor->data.power.out_path, fname_buff,
                           HWMON_BASE_IDX + name_len, HWMON_POWER_OUT);

        // Temperature
        set_file_if_exists(sensor->data.temp.in_path, fname_buff,
                           HWMON_BASE_IDX + name_len, HWMON_TEMP_IN);
        set_file_if_exists(sensor->data.temp.out_path, fname_buff,
                           HWMON_BASE_IDX + name_len, HWMON_TEMP_OUT);

#define __EXISTS(sensro, type, path) ((sensor)->data.type.path[0] != '\0')
#define AT_LEAST_ONE_EXISTS(sensor, type)                                      \
    (__EXISTS(sensor, type, in_path) || __EXISTS(sensor, type, out_path))

        // Check, if none of these files exists there's no
        // point in adding the sensor at all!
        if (AT_LEAST_ONE_EXISTS(sensor, current) ||
            AT_LEAST_ONE_EXISTS(sensor, voltage) ||
            AT_LEAST_ONE_EXISTS(sensor, power) ||
            AT_LEAST_ONE_EXISTS(sensor, temp)) {
            // Add to list
            list_add(&sensor->base.list, list);
        } else {
            free(sensor);
        }
    }

    closedir(dir);
}

#define READLONG_OR_BUST(path) (((path)[0] == '\0') ? 0 : readlong(path))

static inline void hwmon_readmeasure(struct hwmon_measure *measure) {
    measure->in_value = READLONG_OR_BUST(measure->in_path);
    measure->out_value = READLONG_OR_BUST(measure->out_path);
    measure->diff_value = labs(measure->in_value - measure->out_value);
}

// ------------------- Public Methods ------------------- //

void sensor_hwmon_close(struct sensor *sself __attribute((unused))) {}

int sensor_hwmon_read(struct sensor *sself) {
    struct sensor_hwmon *self = (struct sensor_hwmon *)sself;

    hwmon_readmeasure(&self->data.current);
    hwmon_readmeasure(&self->data.voltage);
    hwmon_readmeasure(&self->data.power);
    hwmon_readmeasure(&self->data.temp);

    return 0;
}

#define NAME(self) ((self)->data.name)
#define CURRENT_uA(self) ((self)->data.current.diff_value * 1000L)
#define VOLTAGE_uV(self) ((self)->data.voltage.diff_value * 1000L)
#define POWER_uW(self) ((self)->data.power.diff_value)
#define TEMP_mC(self) ((self)->data.temp.diff_value)

void sensor_hwmon_print_last(struct sensor *sself) {
    struct sensor_hwmon *self = (struct sensor_hwmon *)sself;

    printf("hwmon_%s_uA %ld\n", NAME(self), CURRENT_uA(self));
    printf("hwmon_%s_uV %ld\n", NAME(self), VOLTAGE_uV(self));
    printf("hwmon_%s_uW %ld\n", NAME(self), POWER_uW(self));
    printf("hwmon_%s_mC %ld\n", NAME(self), TEMP_mC(self));
}

// =========================================================
// SENSORS DETECTION AND INITIALIZATION
// =========================================================

struct list_head *sensors_hwmon_init() {
    struct list_head *list = list_new();
    if (list == NULL)
        exit(EXIT_FAILURE);

    sensor_hwmon_getlist(list);

    return list;
}
