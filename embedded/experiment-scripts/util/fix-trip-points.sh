#!/bin/bash

# NOTE: these functions are kind of custom, use with caution

function activate_pwm_fans() {
    local PREFIX=/sys/devices/virtual/thermal/thermal_zone
    for tz in "${PREFIX}"*; do
        j=$(echo "$tz" | sed "s#${PREFIX}##")
        if [ "$j" = '*' ]; then
            continue
        fi
        for tp in "$tz"/trip_point_*_temp; do
            if [ "$tp" = "$tz"'/trip_point_*_temp' ]; then
                continue
            fi

            i=$(echo "$tp" | sed "s#${tz}/trip_point_##" | sed "s#_temp##")
            type=$(cat "${tz}/trip_point_${i}_type")
            if [ "$type" = "active" ]; then
                echo "15000" >"${tp}"
            fi
        done
    done

    # Set maximum speed for integrated PWM fan if available
    if [ -d /sys/devices/platform/pwm-fan/hwmon/hwmon0/ ]; then
        (
            set +e

            echo "252 253 254 255" >/sys/devices/platform/pwm-fan/hwmon/hwmon0/fan_speed
            echo "0" >/sys/devices/platform/pwm-fan/hwmon/hwmon0/automatic
            echo "1" >/sys/devices/platform/pwm-fan/hwmon/hwmon0/pwm1_enable
            echo "255" >/sys/devices/platform/pwm-fan/hwmon/hwmon0/pwm1
        ) 2>/dev/null
    fi
}

function print_trip_points() {
    local PREFIX=/sys/devices/virtual/thermal/thermal_zone
    for tz in "${PREFIX}"*; do
        j=$(echo "$tz" | sed "s#${PREFIX}##")
        if [ "$j" = '*' ]; then
            continue
        fi
        echo "====> ZONE: $j"
        for tp in "$tz"/trip_point_*_temp; do
            i=$(echo "$tp" | sed "s#${tz}/trip_point_##" | sed "s#_temp##")
            temp=$(cat "${tz}/trip_point_${i}_temp" || echo "")
            type=$(cat "${tz}/trip_point_${i}_type" || echo "")
            hyst=$(cat "${tz}/trip_point_${i}_hyst" || echo "")
            echo -e "INDEX: $i\tTEMP: ${temp}\tTYPE: ${type}\tHYST: ${hyst}"
        done
    done
}
