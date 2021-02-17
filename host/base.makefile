# +--------------------------------------------------------+
# |                       Functions                        |
# +--------------------------------------------------------+

# Defines a bunch of shell functions to be used later (GNU Make only)
def_funs = \
find_suffixes() { \
	find . -name $$1'*' | sort | uniq | sed 's/.*'$$1'//' | sort -n | uniq ; \
}

# +--------------------------------------------------------+
# |               Parameters (auto inferred)               |
# +--------------------------------------------------------+

howmanies   = $(shell $(def_funs); find_suffixes 'howmany_')
policies    = $(shell $(def_funs); find_suffixes 'policy_')
freqs       = $(shell $(def_funs); find_suffixes 'freq_')
tasks       = $(shell $(def_funs); find_suffixes 'task_')

# head is for debug
orig_measure_power_files = $(shell find . -name 'measure_power.txt')
orig_measure_time_files  = $(shell find . -name 'measure_time.txt' )

raw_measure_power_files  = $(patsubst %measure_power.txt,%raw_measure_power.csv,$(orig_measure_power_files))
raw_measure_time_files   = $(patsubst %measure_time.txt,%raw_measure_time.csv,$(orig_measure_time_files))

raw_measure_files        = $(raw_measure_time_files) $(raw_measure_power_files)

col_opt ?= ''

.PHONY: all
all: $(raw_measure_files)

raw_measure_%.csv: measure_%.txt
	raw_to_csv.py -c $(col_opt) -o $@ $<
