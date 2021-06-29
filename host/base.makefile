col_opt ?= ''
GENERATED_DEPS ?= ''

.PHONY: all
all: outdata.csv

raw_measure_power.csv: measure_power.txt
	raw_to_csv.py -c $(col_opt) -o $@ $<

raw_measure_time%.csv: measure_time.txt%
	raw_to_csv.py -c $(col_opt) -o $@ $<

-include $(GENERATED_DEPS)
