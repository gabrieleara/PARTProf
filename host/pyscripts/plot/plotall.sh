#!/bin/bash

for f in $(find ./data/results/odroid-xu4-thermal/ -name 'raw*power*'); do
    i=$(echo $f | sed 's#raw_measure_power.csv#plot_power_temp#')
    ./host/pyscripts/plot/plot_time.py \
        -y1 sensor_cpu_uW \
        -y2 thermal_zone_temp0 \
        -y2 thermal_zone_temp1 \
        -y2 thermal_zone_temp2 \
        -y2 thermal_zone_temp3 \
        -Y1 'Power [ µW ]' \
        -Y2 'Temperature [ mC ]' \
        "$f" \
        -o "$i" \
        -O ".pdf" &
done
