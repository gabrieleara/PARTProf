col_opt ?= ''
GENERATED_DEPS ?= ''

.PHONY: all
all: outdata.csv # allsamples.csv

%raw_measure_power.csv: %measure_power.txt
	raw_to_csv.py -c $(col_opt) -o $@ $<

raw_measure_time%.csv: measure_time.txt%
	perf_csv_to_csv.py -o $@ $<

-include $(GENERATED_DEPS)
