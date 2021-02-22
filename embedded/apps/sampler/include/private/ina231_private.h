#ifndef SENSOR_INA231_PRIV_H
#define SENSOR_INA231_PRIV_H

// ----------------------- Private constants and defines -----------------------

typedef enum {
    SENSOR_DISABLED = 0,
    SENSOR_ENABLED = 1,
} sensor_ina231_enable_t;

// IOCTL Operations
#define INA231_IOCGREG _IOR('i', 1, struct sensor_ina231_iocreg_t *)
#define INA231_IOCSSTATUS _IOW('i', 2, struct sensor_ina231_iocreg_t *)
#define INA231_IOCGSTATUS _IOR('i', 3, struct sensor_ina231_iocreg_t *)

// ---------------------------------------------------------

// List of possible INA231 sensors
enum {
    INA231_SENSOR_ARM = 0, // Cortex-A15 Core  = BIG
    INA231_SENSOR_MEM,     // GPU
    INA231_SENSOR_KFC,     // Cortex-A7 Core   = LITTLE
    INA231_SENSOR_G3D,     // GPU
    INA231_SENSOR_MAX
};

//----------------------------------------------------------

// List of all device paths for each INA231 sensor
#define DEV_SENSOR_ARM "/dev/sensor_arm"
#define DEV_SENSOR_MEM "/dev/sensor_mem"
#define DEV_SENSOR_KFC "/dev/sensor_kfc"
#define DEV_SENSOR_G3D "/dev/sensor_g3d"

#define DEV_NAME_LEN sizeof(DEV_SENSOR_ARM)

static const char DEV_SENSORS[][DEV_NAME_LEN] = {
    DEV_SENSOR_ARM,
    DEV_SENSOR_MEM,
    DEV_SENSOR_KFC,
    DEV_SENSOR_G3D,
};

//----------------------------------------------------------

// List of all device paths for each INA231 sensor update period
#define DEV_UPDATE_PERIOD_BASE "/sys/bus/i2c/drivers/INA231/"
#define DEV_UPDATE_PERIOD "/update_period"

#define SENSOR_PREFIX "0" // Kernel 4.9+
// #define SENSOR_PREFIX "3" // Kernel 3.9

#define DEV_UPDATE_PERIOD_ARM                                                  \
    DEV_UPDATE_PERIOD_BASE SENSOR_PREFIX "-0040" DEV_UPDATE_PERIOD
#define DEV_UPDATE_PERIOD_MEM                                                  \
    DEV_UPDATE_PERIOD_BASE SENSOR_PREFIX "-0041" DEV_UPDATE_PERIOD
#define DEV_UPDATE_PERIOD_KFC                                                  \
    DEV_UPDATE_PERIOD_BASE SENSOR_PREFIX "-0045" DEV_UPDATE_PERIOD
#define DEV_UPDATE_PERIOD_G3D                                                  \
    DEV_UPDATE_PERIOD_BASE SENSOR_PREFIX "-0044" DEV_UPDATE_PERIOD

#define DEV_UPDATE_PERIOD_LEN sizeof(DEV_UPDATE_PERIOD_ARM)

static const char DEV_UPDATE_PERIODS[][DEV_UPDATE_PERIOD_LEN] = {
    DEV_UPDATE_PERIOD_ARM,
    DEV_UPDATE_PERIOD_MEM,
    DEV_UPDATE_PERIOD_KFC,
    DEV_UPDATE_PERIOD_G3D,
};

//----------------------------------------------------------

#endif // SENSOR_INA231_PRIV_H
