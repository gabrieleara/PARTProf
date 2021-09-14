#include <locale.h>

#include "private/smartpower_private.h"
#include "readfile.h"
#include "sensor_smartpower.h"

// =========================================================
// SINGLE SENSOR
// =========================================================

#define __SENSOR_SMARTPOWER_BASE_INITIALIZER                                   \
    {                                                                          \
        {}, -1, "", sensor_smartpower_read, sensor_smartpower_close,           \
            sensor_smartpower_print_last,                                      \
    }

#define __SENSOR_SMARTPOWER_INITIALIZER                                        \
    { __SENSOR_SMARTPOWER_BASE_INITIALIZER, NULL, 0, 0, 0, 0, 0, }

const struct sensor_smartpower SENSOR_SMARTPOWER_INITIALIZER =
    __SENSOR_SMARTPOWER_INITIALIZER;

// ------------------ Private Methods ------------------- //

static inline int sensor_smartpower_connected(struct sensor_smartpower *self) {
    return self->device != 0;
}

// -1 on error
static inline int
sensor_smartpower_write_request(struct sensor_smartpower *self,
                                enum hid_request_code request_code) {
    if (!sensor_smartpower_connected(self))
        goto error;

    struct hid_request request;
    request.request_code = REQUEST_NONE;
    request.payload.out_request_code = request_code;

    if (hid_write(self->device, (byte_t *)&request, sizeof(request)) < 0)
        goto error;

    return 0;

error:
    sensor_smartpower_close((struct sensor *)self);
    return -1;
}

#define REQ_RAW(request) ((request).payload.raw)
#define REQ_STATUS(request) ((request).payload.status)
#define REQ_DATA(request) ((request).payload.data)

int sensor_smartpower_read_response(struct sensor_smartpower *self) {
    if (!sensor_smartpower_connected(self))
        goto error;

    struct hid_request request;
    int nread = hid_read(self->device, (byte_t *)&request, sizeof(request));
    if (nread < 0)
        goto error;

    switch (request.request_code) {
    case REQUEST_VERSION:
        // TODO: implement
        break;
    case REQUEST_STATUS:
        self->is_on = REQ_STATUS(request).is_on & 0x01;
        self->is_started = REQ_STATUS(request).is_started & 0x01;
        break;
    case REQUEST_DATA:
        // Forces string termination after each read value
        REQ_DATA(request)._padding_1[0] = '\0';
        REQ_DATA(request)._padding_2[0] = '\0';
        REQ_DATA(request)._padding_3[0] = '\0';

        // These strings are all null-terminated now
        self->voltage = atof((char *)REQ_DATA(request).voltage);
        self->current = atof((char *)REQ_DATA(request).current);
        self->power = atof((char *)REQ_DATA(request).power);
        break;
    default:
        goto error;
    }

    return 0;

error:
    sensor_smartpower_close((struct sensor *)self);
    return -1;
}

struct sensor_smartpower *sensor_smartpower_new() {
    struct sensor_smartpower *ptr = malloc(sizeof(struct sensor_smartpower));
    if (ptr != NULL)
        *ptr = SENSOR_SMARTPOWER_INITIALIZER;
    return ptr;
}

// Check that the given file exists
// Success if return >= 0
int sensor_smartpower_open(struct sensor_smartpower *self) {
    // This operation modifies the current locale for the application, I
    // re-apply default C locale to avoid problems in doubles conversion
    self->device = hid_open(HID_VENDOR_ID, HID_PRODUCT_ID, HID_SERIAL_NUMBER);
    setlocale(LC_ALL, "C");

    if (!sensor_smartpower_connected(self))
        return -1;

    int res;

    res = sensor_smartpower_write_request(self, REQUEST_STATUS);
    if (res < 0)
        goto error;
    res = sensor_smartpower_read_response(self);
    if (res < 0)
        goto error;

    // // This can't be possible if the sensor is powering the
    // // board itself!
    // if (!self->is_on) {
    //     // ERROR!
    //     sensor_smartpower_write_request(self, REQUEST_ONOFF);
    // }

    // // I don't really care in what state the smartpower is
    // if (self->is_started) {
    //     res = sensor_smartpower_write_request(smartpower, REQUEST_STARTSTOP);
    //     if (res < 0)
    //         goto error;
    // }

    return 0;

error:
    sensor_smartpower_close((struct sensor *)self);
    return -1;
}

// ------------------- Public Methods ------------------- //

// Close a connection with the file driver
void sensor_smartpower_close(struct sensor *sself) {
    struct sensor_smartpower *self = (struct sensor_smartpower *)sself;
    hid_close(self->device);
    self->device = NULL;
}

// Read data from the file driver
// Success if return >= 0
int sensor_smartpower_read(struct sensor *sself) {
    struct sensor_smartpower *self = (struct sensor_smartpower *)sself;
    int res;

    // res = sensor_smartpower_write_request(smartpower, REQUEST_STATUS);
    // if (res < 0)
    //     goto end;

    // res = sensor_smartpower_read_response(smartpower);
    // if (res < 0)
    //     goto end;

    res = sensor_smartpower_write_request(self, REQUEST_DATA);
    if (res < 0)
        goto end;

    res = sensor_smartpower_read_response(self);
    if (res < 0)
        goto end;

end:
    return res;
}

#include <stdio.h>

void sensor_smartpower_print_last(struct sensor *sself) {
    struct sensor_smartpower *self = (struct sensor_smartpower *)sself;

    // printf("STATUS: %s %s\n", self->is_on ? "ON" : "OFF",
    //        self->is_started ? "START" : "STOP");

    printf("smartpower uV %ld\n", (long)(self->voltage * 1000000.0));
    printf("smartpower uA %ld\n", (long)(self->current * 1000000.0));
    printf("smartpower uW %ld\n", (long)(self->power * 1000000.0));
}

// =========================================================
// MULTIPLE SENSORS DETECTION AND INITIALIZATION
// =========================================================

struct list_head *sensors_smartpower_init() {
    struct list_head *list = list_new();
    if (list == NULL)
        exit(EXIT_FAILURE);

    struct sensor_smartpower *s = sensor_smartpower_new();
    if (s == NULL)
        exit(EXIT_FAILURE);

    int res = sensor_smartpower_open(s);
    if (res < 0)
        free(s);
    else
        list_add_tail(&s->base.list, list);

    return list;
}
