#ifndef HWMON_PRIVATE_H
#define HWMON_PRIVATE_H

#define HWMON_DIR "/sys/class/hwmon/"
#define HWMON_NAME "/name"
#define HWMON_CURR_IN "/curr1_input"
#define HWMON_VOLT_IN "/in1_input"
#define HWMON_CURR_OUT "/curr2_input"
#define HWMON_VOLT_OUT "/in2_input"
#define HWMON_POWER_IN "/power1_input"
#define HWMON_POWER_OUT "/power2_input"
#define HWMON_TEMP_IN "/temp1_input"
#define HWMON_TEMP_OUT "/temp2_input"

#define HWMON_BASE_IDX (sizeof(HWMON_DIR) - 1)

#endif // HWMON_PRIVATE_H
