col_opt ?= ''
GENERATED_DEPS ?= ''

.PHONY: all
all: outdata.csv

raw_measure_%.csv: measure_%.txt
	raw_to_csv.py -c $(col_opt) -o $@ $<

-include $(GENERATED_DEPS)
