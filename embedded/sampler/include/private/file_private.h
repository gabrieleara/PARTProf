#ifndef SENSOR_FILE_PRIV_H
#define SENSOR_FILE_PRIV_H

#define DEV_NAME_CPUFREQ "cpu_freq"
#define DEV_PATH_CPUFREQ_BASE "/sys/devices/system/cpu/cpu"
#define DEV_PATH_CPUFREQ_END "/cpufreq/scaling_cur_freq"

#define DEV_NAME_THERMAL "thermal_zone_temp"
#define DEV_PATH_THERMAL_BASE "/sys/devices/virtual/thermal/thermal_zone"
#define DEV_PATH_THERMAL_END "/temp"

#define DEV_NAME_CPUFAN "cpu_fan"
#define DEV_PATH_CPUFAN "/sys/devices/platform/pwm-fan/hwmon/hwmon0/pwm1"

#endif // SENSOR_FILE_PRIV_H
