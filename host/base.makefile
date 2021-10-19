CMAP_FILE       ?= ''
GENERATED_RULES ?= ''

.PHONY: all

all: global_table.csv

%table_power.csv: %measure_power.txt
	power_samples_to_table.py -c $(CMAP_FILE) -o $@ $<

table_perf.%.csv: measure_time.txt.%
	perf_samples_to_table.py -c $(CMAP_FILE) -o $@ $<

# TODO: implement this part
global_table.csv: collapsed_table_power.csv th_megadb.csv # collapsed_table_perf.csv
	cp $< $@

-include $(GENERATED_RULES)
