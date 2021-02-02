// These lines are specific to the UltraScale+ ZCU 102 but they can be easily
// changed to fit other boards as well

// A big part of this code is inspired or taken from Don Matson and Luis Bielich
// blog post:
// https://developer.xilinx.com/en/articles/accurate-design-power-measurement.html

enum INA226_US_PLUS_ZCU_102_RAIL {
    // PS Lines
    VCCPSINTFP = 0,
    VCCINTLP,
    VCCPSAUX,
    VCCPSPLL,
    MGTRAVCC,
    MGTRAVTT,
    VCCPSDDR,
    VCCOPS,  // NOTICE: ARM debug subsystem (skip)
    VCCOPS3, // NOTICE: ARM debug subsystem (skip)
    VCCPSDDRPLL,

    // PL Lines
    VCCINT,
    VCCBRAM,
    VCCAUX,
    VCC1V2,
    VCC3V3,
    VADJ_FMC,
    MGTAVCC,
    MGTAVTT,
};

#define PS_MIN VCCPSINTFP
#define PS_MAX (VCCPSDDRPLL + 1)

#define PL_MIN VCCINT
#define PL_MAX (MGTAVTT + 1)

struct string_pair {
    char railname[16];
    char linename[16];
};

const struct string_pair ina226_lines[] = {
    // PS Lines
    {"VCCPSINTFP", "ina226_u76"},
    {"VCCINTLP", "ina226_u77"},
    {"VCCPSAUX", "ina226_u78"},
    {"VCCPSPLL", "ina226_u87"},
    {"MGTRAVCC", "ina226_u85"},
    {"MGTRAVTT", "ina226_u86"},
    {"VCCPSDDR", "ina226_u93"},
    {"VCCOPS", "ina226_u88"},
    {"VCCOPS3", "ina226_u15"},
    {"VCCPSDDRPLL", "ina226_u92"},

    // PL Lines
    {"VCCINT", "ina226_u79"},
    {"VCCBRAM", "ina226_u81"},
    {"VCCAUX", "ina226_u80"},
    {"VCC1V2", "ina226_u84"},
    {"VCC3V3", "ina226_u16"},
    {"VADJ_FMC", "ina226_u65"},
    {"MGTAVCC", "ina226_u74"},
    {"MGTAVTT", "ina226_u75"},
};

#define HWMON_DIR "/sys/class/hwmon/"
#define HWMON_NAME "/name"
#define HWMON_CURR_IN "/curr1_input"
#define HWMON_VOLT_IN "/in1_input"
#define HWMON_CURR_OUT "/curr2_input"
#define HWMON_VOLT_OUT "/in2_input"
#define HWMON_POWER_IN "/power1_input"
#define HWMON_POWER_OUT "/power2_input"

#define HWMON_BASE_IDX (sizeof(HWMON_DIR) - 1)
