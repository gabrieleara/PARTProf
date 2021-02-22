#ifndef SENSOR_SMARTPOWER_PRIVATE_H
#define SENSOR_SMARTPOWER_PRIVATE_H

#include <stdint.h>

typedef uint8_t byte_t;

#define HID_VENDOR_ID 0x04d8
#define HID_PRODUCT_ID 0x003f
#define HID_SERIAL_NUMBER NULL

enum hid_request_code {
    REQUEST_NONE = 0x00,
    REQUEST_DATA = 0x37,
    REQUEST_STARTSTOP = 0x80,
    REQUEST_STATUS = 0x81,
    REQUEST_ONOFF = 0x82,
    REQUEST_VERSION = 0x83,
};

#define HID_PAYLOAD_SIZE 64

struct __attribute__((__packed__)) hid_req_status {
    byte_t is_started;
    byte_t is_on;
};

struct __attribute__((__packed__)) hid_req_data {
    byte_t _padding_0[1];
    byte_t voltage[5];
    byte_t _padding_1[3];
    byte_t current[6];
    byte_t _padding_2[2];
    byte_t power[5];
    byte_t _padding_3[1];
};

union hid_req_payload {
    byte_t out_request_code;
    struct hid_req_status status;
    struct hid_req_data data;
    byte_t raw[HID_PAYLOAD_SIZE];
};

struct __attribute__((__packed__)) hid_request {
    byte_t request_code;
    union hid_req_payload payload;
};

#define REQ_RAW(request) ((request).payload.raw)
#define REQ_STATUS(request) ((request).payload.status)
#define REQ_DATA(request) ((request).payload.data)

#endif // SENSOR_SMARTPOWER_PRIVATE_H
