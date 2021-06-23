#!/bin/bash

function trip_points_print() {
    local TRIP_PREFIX=/sys/devices/virtual/thermal/thermal_zone
    local thermal_zone
    local trip_point
    local tp_temp
    local tp_type
    local tp_hyst
    local tp_temp_v
    local tp_type_v
    local tp_hyst_v

    # For each thermal_zone (even non-used ones)
    for thermal_zone in "${TRIP_PREFIX}"*; do
        # Get the index of the thermal zone
        j=$(echo "$thermal_zone" | sed "s#${TRIP_PREFIX}##")
        if [ "$j" = '*' ]; then
            continue
        fi

        tp_prefix="$thermal_zone"/trip_point_
        tp_temp=_temp
        tp_type=_type
        tp_hyst=_hyst

        # For each trip point
        for trip_point in "$tp_prefix"*"$tp_temp"; do
            i=$(echo "$trip_point" |
                sed "s#${tp_prefix}\([[:digit:]]\+\)${tp_temp}#\1#")
            if [ "$i" = '*' ]; then
                continue
            fi

            tp_temp_v=$(cat ${tp_prefix}${i}${tp_temp} 2>/dev/null || echo '')
            tp_type_v=$(cat ${tp_prefix}${i}${tp_type} 2>/dev/null || echo '')
            tp_hyst_v=$(cat ${tp_prefix}${i}${tp_hyst} 2>/dev/null || echo '')

            pinfo1 "Thermal zone $j, trip point $i:"
            pinfo2 " temp: ${tp_temp_v}"
            pinfo2 " type: ${tp_type_v}"
            pinfo2 " hyst: ${tp_hyst_v}"
        done
    done
}


# NOTICE: now it requires a reboot for it to take effect, for some reason!
function trip_points_force_fan() {
    # This first operation does not require a reboot, but it is supported only
    # on kernel 4.14.20 or higher, and not on kernel 5.4.
    # We run it anyway and if it fails, oh well.

    # Using this method, the fan ignores written scaling
    # files (trip points and fan speed) and runs
    # constantly at the same speed.
    echo '0' >/sys/devices/platform/pwm-fan/hwmon/hwmon0/automatic 2>/dev/null || true
    echo '255' >/sys/devices/platform/pwm-fan/hwmon/hwmon0/pwm1 2>/dev/null || true

    # Since we want always the fan to be active, we will modify its trip points
    # so that they will fire up immediately

    local TRIP_PREFIX=/sys/devices/virtual/thermal/thermal_zone
    local thermal_zone
    local trip_point
    local tp_prefix
    local tp_temp
    local tp_type
    local tp_hyst
    local tp_temp_v
    local tp_type_v
    local tp_hyst_v

    # For each thermal_zone (even non-used ones)
    for thermal_zone in "${TRIP_PREFIX}"*; do
        # Get the index of the thermal zone
        j=$(echo "$thermal_zone" | sed "s#${TRIP_PREFIX}##")
        if [ "$j" = '*' ]; then
            continue
        fi

        tp_prefix="$thermal_zone"/trip_point_
        tp_temp=_temp
        tp_type=_type
        tp_hyst=_hyst

        # For each trip point
        for trip_point in "$tp_prefix"*"$tp_temp"; do
            i=$(echo "$trip_point" |
                sed "s#${tp_prefix}\([[:digit:]]\+\)${tp_temp}#\1#")
            if [ "$i" = '*' ]; then
                continue
            fi

            tp_type_v=$(cat ${tp_prefix}${i}${tp_type} 2>/dev/null || echo '')

            if [ "$tp_type_v" = 'passive' ]; then
                tp_type_v='active'
                echo "$tp_type_v" >"${tp_prefix}${i}${tp_type}" 2>/dev/null || true
            fi

            tp_type_v=$(cat ${tp_prefix}${i}${tp_type} 2>/dev/null || echo '')

            # Set trip temperatures as increasing values from 10°C as the trip temperature
            if [ "$tp_type_v" = 'active' ]; then
                tp_temp_v=$((10000 + i * 1000))
                echo "$tp_temp_v" >"${tp_prefix}${i}${tp_temp}" 2>/dev/null || true
            fi
        done
    done

    trip_points_print
}
