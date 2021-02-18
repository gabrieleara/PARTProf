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

orig_measure_time_files_1  = $(shell find . -name 'measure_time_1.txt')
orig_measure_time_files_2  = $(shell find . -name 'measure_time_2.txt')
orig_measure_time_files_3  = $(shell find . -name 'measure_time_3.txt')
orig_measure_time_files_4  = $(shell find . -name 'measure_time_4.txt')

raw_measure_power_files  = $(patsubst %measure_power.txt,%raw_measure_power.csv,$(orig_measure_power_files))

raw_measure_time_files_1 = $(patsubst %measure_time_1.txt,%raw_measure_time_1.csv,$(orig_measure_time_files_1))
raw_measure_time_files_2 = $(patsubst %measure_time_2.txt,%raw_measure_time_2.csv,$(orig_measure_time_files_2))
raw_measure_time_files_3 = $(patsubst %measure_time_3.txt,%raw_measure_time_3.csv,$(orig_measure_time_files_3))
raw_measure_time_files_4 = $(patsubst %measure_time_4.txt,%raw_measure_time_4.csv,$(orig_measure_time_files_4))

raw_measure_time_files   = $(raw_measure_time_files_1) $(raw_measure_time_files_2) $(raw_measure_time_files_3) $(raw_measure_time_files_4)

raw_measure_files        = $(raw_measure_time_files) $(raw_measure_power_files)

col_opt ?= ''

.PHONY: all
all: $(raw_measure_files)

raw_measure_%.csv: measure_%.txt
	raw_to_csv.py -c $(col_opt) -o $@ $<
